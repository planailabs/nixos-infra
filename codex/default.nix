{ inputs, lib, pkgs, ... }: with lib;
let
  # Official litellm image with the database/proxy stack (prisma engines +
  # migrations) baked in. The nixpkgs litellm package can't do DB mode (no
  # litellm_proxy_extras, no generated prisma client), so for virtual keys /
  # spend tracking / the admin UI we run the upstream image instead. Tracked by
  # the `main-stable` tag (not a digest) so the litellm-image-update timer can
  # pull newer builds.
  litellmImage = "ghcr.io/berriai/litellm-database:main-stable";

  # Reported to the Codex models endpoint (it requires a client_version); track
  # the codex CLI package so it stays current. Used by both the config generator
  # and the provider's runtime discovery.
  codexClientVersion = pkgs.codex.version;

  # Where the assembled config dir lives on the host (bind-mounted into /config).
  configDir = "/var/lib/litellm-codex";

  # Handler shim. litellm resolves `custom_handler` as a file RELATIVE to the
  # config dir (not as an installed module), so this re-exports the provider
  # instance. It also drops any discovered model that collides with litellm's
  # built-in OpenAI model list: litellm's dispatch routes a model in that list to
  # its OpenAI handler BEFORE consulting the custom-provider map, which would send
  # our codex models to OpenAI (and fail). Done dynamically -- no hardcoded names.
  codexHandlerPy = ''
    import litellm
    from litellm_codex_oauth_provider import codex_auth_provider
    try:
        from litellm_codex_oauth_provider.models import available_model_slugs
        for _m in available_model_slugs():
            while _m in litellm.open_ai_chat_completion_models:
                litellm.open_ai_chat_completion_models.remove(_m)
    except Exception:
        pass
  '';

  # Static files mounted into the container (handler shim + pure-Python provider
  # source, importable via PYTHONPATH=/config). config.yaml is generated at start
  # from the live model list -- see genLitellmConfig.
  litellmStaticDir = pkgs.runCommand "litellm-codex-static" { } ''
    mkdir -p "$out"
    cp ${pkgs.writeText "codex_handler.py" codexHandlerPy} "$out/codex_handler.py"
    cp -r ${pkgs.litellm-codex-oauth-provider}/lib/python*/site-packages/litellm_codex_oauth_provider "$out/"
  '';

  # Assemble ${configDir} at each start: copy the static files, then write a
  # config.yaml whose model_list is the account's live, API-usable models (from
  # GET /backend-api/codex/models). No hardcoded model names; falls back to a
  # small recent set only if discovery fails. config.yaml is emitted as JSON,
  # which litellm parses as YAML.
  genLitellmConfig = pkgs.writers.writePython3Bin "litellm-codex-genconfig"
    { flakeIgnore = [ "E501" "W503" "W504" "E731" "E302" "E305" "E306" ]; } ''
    import base64
    import html
    import json
    import os
    import re
    import shutil
    import sys
    import urllib.parse
    import urllib.request

    STATIC = "${litellmStaticDir}"
    OUT = "${configDir}"
    AUTH = os.environ.get("CODEX_AUTH_FILE", "/root/.codex/auth.json")
    CLIENT_VERSION = os.environ.get("CODEX_CLIENT_VERSION", "${codexClientVersion}")
    FALLBACK = ["gpt-5.5", "gpt-5.4", "gpt-5.4-mini"]
    PRICING_URL = "https://developers.openai.com/api/docs/pricing"

    os.makedirs(OUT, exist_ok=True)
    for name in os.listdir(STATIC):
        src = os.path.join(STATIC, name)
        dst = os.path.join(OUT, name)
        if os.path.isdir(src):
            shutil.rmtree(dst, ignore_errors=True)
            shutil.copytree(src, dst)
        else:
            shutil.copyfile(src, dst)


    def discover():
        with open(AUTH) as fh:
            data = json.load(fh)
        tok = data.get("tokens") or data.get("chatgpt") or data
        access = tok["access_token"]
        account = tok.get("account_id")
        if not account:
            seg = access.split(".")[1]
            seg += "=" * (-len(seg) % 4)
            claims = json.loads(base64.urlsafe_b64decode(seg))
            account = claims["https://api.openai.com/auth"]["chatgpt_account_id"]
        query = urllib.parse.urlencode({"client_version": CLIENT_VERSION})
        req = urllib.request.Request(
            "https://chatgpt.com/backend-api/codex/models?" + query,
            headers={
                "Authorization": "Bearer " + access,
                "chatgpt-account-id": account,
                "OpenAI-Beta": "responses=experimental",
                "originator": "codex_cli_rs",
            },
        )
        with urllib.request.urlopen(req, timeout=20) as resp:
            models = json.load(resp).get("models", [])
        return [
            m["slug"]
            for m in models
            if m.get("slug")
            and m.get("supported_in_api", True)
            and m.get("visibility", "list") == "list"
        ]


    def fetch_pricing():
        # The Codex models endpoint has no pricing (subscription), so scrape the
        # public OpenAI pricing page. Prices are embedded as encoded rows shaped
        # like [0,"<model> (...)"],[0,<input>],[0,<cached>],[0,<output>] (per 1M
        # tokens); the first table is Standard pricing. Best-effort: {} on failure.
        try:
            req = urllib.request.Request(PRICING_URL, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=20) as resp:
                raw = html.unescape(resp.read().decode("utf-8", "replace"))
        except Exception as exc:  # noqa: BLE001
            sys.stderr.write("codex pricing fetch failed (%s)\n" % exc)
            return {}
        pat = re.compile(
            r'\[0,"([a-zA-Z0-9.\-]+)[^"]*"\],\[0,([\d.]+)\],\[0,([\d.]+)\],\[0,([\d.]+)\]'
        )
        prices = {}
        for m in pat.finditer(raw):
            name = m.group(1)
            if name not in prices:  # keep the first (Standard) table
                prices[name] = (float(m.group(2)), float(m.group(3)), float(m.group(4)))
        return prices

    try:
        slugs = discover() or FALLBACK
    except Exception as exc:  # noqa: BLE001
        sys.stderr.write("codex model discovery failed (%s); using fallback\n" % exc)
        slugs = FALLBACK

    prices = fetch_pricing()

    def params(slug):
        out = {"model": "codex/" + slug}
        price = prices.get(slug)
        if price:
            inp, cached, outp = price
            out["input_cost_per_token"] = inp / 1_000_000
            out["output_cost_per_token"] = outp / 1_000_000
            out["cache_read_input_token_cost"] = cached / 1_000_000
        return out

    config = {
        "general_settings": {"master_key": "os.environ/LITELLM_MASTER_KEY"},
        "litellm_settings": {
            "custom_provider_map": [
                {"provider": "codex", "custom_handler": "codex_handler.codex_auth_provider"}
            ]
        },
        "model_list": [{"model_name": s, "litellm_params": params(s)} for s in slugs],
    }
    priced = [s for s in slugs if s in prices]
    sys.stderr.write("priced models: %s\n" % ", ".join(priced))
    with open(os.path.join(OUT, "config.yaml"), "w") as fh:
        json.dump(config, fh, indent=2)
    sys.stderr.write("litellm model_list: %s\n" % ", ".join(slugs))
  '';
in
{
  imports = [
    ../modules/common.nix
    ../modules/container.nix
    "${inputs.self.private}/codex.nix"
    ./nginx.nix
  ];

  system.stateVersion = "26.11";

  nixpkgs.hostPlatform = "x86_64-linux";

  mkg.mod = {
    yggdrasil = {
      enable = true;
      port = 14466;
      peers = [ "tcp://ygg.mkg20001.io:80" "tls://ygg.mkg20001.io:443" ];
    };
  };

  # Local Postgres backing litellm's virtual keys, spend tracking and admin UI.
  # Loopback-only with trust auth -- this is a single-purpose host and only the
  # litellm container connects (over the shared host network namespace).
  services.postgresql = {
    enable = true;
    enableTCPIP = true;
    settings.listen_addresses = lib.mkForce "127.0.0.1";
    ensureDatabases = [ "litellm" ];
    ensureUsers = [ { name = "litellm"; ensureDBOwnership = true; } ];
    authentication = lib.mkBefore ''
      host litellm litellm 127.0.0.1/32 trust
      host litellm litellm ::1/128 trust
    '';
  };

  # litellm proxy via the official DB image. --network=host so it can reach
  # Postgres on 127.0.0.1 and bind the proxy on 127.0.0.1:8080 for nginx.
  virtualisation.oci-containers = {
    backend = "podman";
    containers.litellm = {
      image = litellmImage;
      extraOptions = [ "--network=host" ];
      cmd = [ "--config" "/config/config.yaml" "--host" "127.0.0.1" "--port" "8080" ];
      # LITELLM_MASTER_KEY comes from the secret file; the rest are non-secret.
      environmentFiles = [ "/etc/litellm.env" ];
      environment = {
        DATABASE_URL = "postgresql://litellm@127.0.0.1:5432/litellm";
        PYTHONPATH = "/config";
        CODEX_AUTH_FILE = "/root/.codex/auth.json";
        CODEX_CLIENT_VERSION = codexClientVersion;
        SCARF_NO_ANALYTICS = "True";
        DO_NOT_TRACK = "True";
        ANONYMIZED_TELEMETRY = "False";
      };
      volumes = [
        "${configDir}:/config:ro"
        # The provider reads and (on refresh) rewrites the Codex tokens here;
        # `codex login` on the host populates it. Mounted rw so refresh persists.
        "/root/.codex:/root/.codex:rw"
      ];
    };
  };

  # Regenerate the litellm config (live model_list) before the container starts.
  systemd.services.litellm-codex-config = {
    description = "Assemble litellm config dir from the live Codex model list";
    before = [ "podman-litellm.service" ];
    requiredBy = [ "podman-litellm.service" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    environment.CODEX_CLIENT_VERSION = codexClientVersion;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${genLitellmConfig}/bin/litellm-codex-genconfig";
    };
  };

  # The container needs Postgres up first (migrations run on start).
  systemd.services.podman-litellm = {
    after = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];
  };

  # Refresh the model list + pricing every 7 days. Restarting the container
  # re-runs litellm-codex-config, which re-discovers models and re-scrapes prices.
  systemd.timers.litellm-codex-refresh = {
    wantedBy = [ "timers.target" ];
    timerConfig = { OnCalendar = "weekly"; Persistent = true; RandomizedDelaySec = "1h"; };
  };
  systemd.services.litellm-codex-refresh = {
    description = "Regenerate the litellm config from live models + pricing";
    serviceConfig.Type = "oneshot";
    serviceConfig.ExecStart = "${pkgs.systemd}/bin/systemctl restart podman-litellm.service";
  };

  # Auto-update the litellm image: pull main-stable weekly and restart only if it
  # actually changed (the restart re-runs migrations + config regen).
  systemd.timers.litellm-image-update = {
    wantedBy = [ "timers.target" ];
    timerConfig = { OnCalendar = "weekly"; Persistent = true; RandomizedDelaySec = "2h"; };
  };
  systemd.services.litellm-image-update = {
    description = "Pull the latest litellm image and restart if changed";
    path = [ pkgs.podman ];
    serviceConfig.Type = "oneshot";
    script = ''
      before="$(podman image inspect --format '{{.Id}}' ${litellmImage} 2>/dev/null || true)"
      podman pull ${litellmImage} || exit 0
      after="$(podman image inspect --format '{{.Id}}' ${litellmImage})"
      if [ "$before" != "$after" ]; then
        systemctl restart podman-litellm.service
      fi
    '';
  };

  # Expose a Docker-compatible socket so docuum can manage podman images.
  virtualisation.podman.dockerSocket.enable = true;

  # LRU-evict old images (e.g. superseded litellm builds) once the image store
  # grows past the threshold. In-use images (the running container) are skipped.
  systemd.services.docuum = {
    description = "LRU eviction of old container images";
    wantedBy = [ "multi-user.target" ];
    after = [ "podman.socket" ];
    environment.DOCKER_HOST = "unix:///run/docker.sock";
    serviceConfig = {
      ExecStart = ''${pkgs.docuum}/bin/docuum --threshold "10 GB"'';
      Restart = "always";
      RestartSec = 30;
    };
  };

  # `codex login` on the host writes /root/.codex/auth.json (mounted into the
  # container); the provider reads and refreshes it in place.
  environment.systemPackages = [ pkgs.codex ];

  security.acme.distributor-server = "https://acme.plan.ai";

  networking.hostName = "codex";
}
