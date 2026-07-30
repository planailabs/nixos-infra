{ inputs, lib, pkgs, ... }: with lib;
let
  # Official litellm image with the database/proxy stack (prisma engines +
  # migrations) baked in. The nixpkgs litellm package can't do DB mode (no
  # litellm_proxy_extras, no generated prisma client), so for virtual keys /
  # spend tracking / the admin UI we run the upstream image instead. Tracked by
  # the `main-stable` tag (not a digest) so the litellm-image-update timer can
  # pull newer builds.
  litellmImage = "ghcr.io/berriai/litellm-database:main-stable";

  # Fallback client_version for the Codex models endpoint (it requires one).
  # The endpoint hides models newer than the reported version and the nixpkgs
  # codex package lags upstream releases, so genLitellmConfig resolves the
  # latest release tag from GitHub at each start and only falls back to the
  # packaged version if that lookup fails. The resolved version is shared with
  # the provider's runtime discovery via ${configDir}/client-version.env.
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

    # Image generation: litellm's get_optional_params_image_gen returns {} for
    # custom providers (its provider-config registry is a hardcoded if/elif over
    # built-in providers), silently dropping the standard n/quality/size/style
    # params before they reach the custom handler. Re-attach them for codex.
    # images/main.py imports the function into its own namespace, so patch the
    # binding there.
    try:
        import litellm.images.main as _img_main
        _orig_img_params = _img_main.get_optional_params_image_gen

        def _codex_img_params(*args, **kwargs):
            out = _orig_img_params(*args, **kwargs)
            if kwargs.get("custom_llm_provider") == "codex":
                for _k in ("n", "quality", "size", "style", "response_format"):
                    if kwargs.get(_k) is not None:
                        out.setdefault(_k, kwargs[_k])
            return out

        _img_main.get_optional_params_image_gen = _codex_img_params
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
    FALLBACK = ["gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna", "gpt-5.5"]
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


    def resolve_client_version():
        # /releases/latest redirects to the latest stable tag (rust-vX.Y.Z);
        # no API call, so no rate limit. Prereleases are never "latest".
        try:
            req = urllib.request.Request(
                "https://github.com/openai/codex/releases/latest",
                headers={"User-Agent": "Mozilla/5.0"},
            )
            with urllib.request.urlopen(req, timeout=20) as resp:
                tag = resp.geturl().rstrip("/").rsplit("/", 1)[-1]
            m = re.match(r"rust-v([0-9][A-Za-z0-9.\-]*)$", tag)
            if m:
                return m.group(1)
            sys.stderr.write("unexpected codex release tag %r; using %s\n" % (tag, CLIENT_VERSION))
        except Exception as exc:  # noqa: BLE001
            sys.stderr.write("codex release lookup failed (%s); using %s\n" % (exc, CLIENT_VERSION))
        return CLIENT_VERSION

    CLIENT_VERSION = resolve_client_version()
    sys.stderr.write("codex client_version: %s\n" % CLIENT_VERSION)
    with open(os.path.join(OUT, "client-version.env"), "w") as fh:
        fh.write("CODEX_CLIENT_VERSION=%s\n" % CLIENT_VERSION)


    def discover():
        # Returns the full model descriptors (not just slugs): input_modalities
        # and context_window feed each entry's model_info below.
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
            m
            for m in models
            if m.get("slug")
            and m.get("supported_in_api", True)
            and m.get("visibility", "list") == "list"
        ]


    def fetch_pricing():
        # The Codex models endpoint has no pricing (subscription), so scrape the
        # public OpenAI pricing page. Prices are embedded as encoded rows shaped
        # like [0,"<model> (...)"],[0,<input>],[0,<cached>],[0,<cache-write>],
        # [0,<output>] (per 1M tokens); a cell is a number or "-" when a model
        # lacks that price. The cache-write column is new with gpt-5.6 -- older
        # rows may have only 3 cells, so accept 3 or 4 and read output from the
        # last. The first table is Standard pricing. Best-effort: {} on failure.
        try:
            req = urllib.request.Request(PRICING_URL, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=20) as resp:
                raw = html.unescape(resp.read().decode("utf-8", "replace"))
        except Exception as exc:  # noqa: BLE001
            sys.stderr.write("codex pricing fetch failed (%s)\n" % exc)
            return {}
        row_pat = re.compile(
            r'\[0,"([a-zA-Z0-9.\-]+)[^"]*"\]((?:,\[0,(?:[\d.]+|"[^"]*")\]){3,4})'
        )
        cell_pat = re.compile(r'\[0,(?:([\d.]+)|"[^"]*")\]')
        prices = {}
        for m in row_pat.finditer(raw):
            name = m.group(1)
            if name in prices:  # keep the first (Standard) table
                continue
            cells = [float(c.group(1)) if c.group(1) else None for c in cell_pat.finditer(m.group(2))]
            inp, cached, outp = cells[0], cells[1], cells[-1]
            cache_write = cells[2] if len(cells) == 4 else None
            if inp is None or outp is None:
                continue
            prices[name] = (inp, cached, cache_write, outp)
        return prices

    try:
        discovered = discover()
    except Exception as exc:  # noqa: BLE001
        sys.stderr.write("codex model discovery failed (%s); using fallback\n" % exc)
        discovered = []
    slugs = [m["slug"] for m in discovered] or FALLBACK
    caps = {m["slug"]: m for m in discovered}

    prices = fetch_pricing()

    def model_info(slug):
        # Advertise capabilities from the discovery payload. Without
        # supports_vision here, litellm reports the model as text-only on
        # /model/info and capability-checking clients refuse to attach images
        # (the wire path itself handles them fine).
        info = {"mode": "chat", "supports_function_calling": True}
        m = caps.get(slug)
        if m:
            info["supports_vision"] = "image" in (m.get("input_modalities") or [])
            if m.get("context_window"):
                info["max_input_tokens"] = m["context_window"]
            # Same reasoning as supports_vision: clients that check
            # /model/info won't send reasoning_effort unless it's advertised.
            levels = [
                lvl.get("effort")
                for lvl in (m.get("supported_reasoning_levels") or [])
                if isinstance(lvl, dict)
            ]
            if levels:
                info["supports_reasoning"] = True
                for effort in ["none", "minimal", "low", "xhigh", "max"]:
                    if effort in levels:
                        info["supports_%s_reasoning_effort" % effort] = True
        return info

    def params(slug):
        # allowed_openai_params: `codex` is a custom provider, so litellm maps
        # params through OpenAILikeChatConfig, whose supported-param list has
        # neither reasoning_effort nor verbosity -- both are dropped before the
        # custom handler is called. Opting in explicitly is the only way to get
        # them through to the provider (which forwards them to `reasoning`/
        # `text` on the Codex /responses payload).
        out = {"model": "codex/" + slug, "allowed_openai_params": ["reasoning_effort", "verbosity"]}
        price = prices.get(slug)
        if price:
            inp, cached, cache_write, outp = price
            out["input_cost_per_token"] = inp / 1_000_000
            out["output_cost_per_token"] = outp / 1_000_000
            if cached is not None:
                out["cache_read_input_token_cost"] = cached / 1_000_000
            if cache_write is not None:
                out["cache_creation_input_token_cost"] = cache_write / 1_000_000
        return out

    config = {
        "general_settings": {"master_key": "os.environ/LITELLM_MASTER_KEY"},
        "litellm_settings": {
            "check_provider_endpoint": True,
            "custom_provider_map": [
                {"provider": "codex", "custom_handler": "codex_handler.codex_auth_provider"}
            ]
        },
        "model_list": (
            [{"model_name": s, "litellm_params": params(s), "model_info": model_info(s)} for s in slugs]
            # Image generation: the Codex backend has no dedicated image models
            # -- the provider fork drives the hosted image_generation tool on a
            # regular codex model (see provider.py:aimage_generation). Expose
            # that under the standard OpenAI image-model names so any image
            # client finds a deployment; all route to the top-priority (first)
            # slug.
            + [
                {
                    "model_name": alias,
                    "litellm_params": {"model": "codex/" + slugs[0]},
                    "model_info": {"mode": "image_generation"},
                }
                for alias in ["gpt-image-2", "gpt-image-1.5", "gpt-image-1", "dall-e-3"]
            ]
            # Sakana AI -- OpenAI-compatible passthrough. `sakana/*` -> `openai/*`
            # forwards the model name after `sakana/` straight to the endpoint.
            + [
                {
                    "model_name": "sakana/*",
                    "litellm_params": {
                        "model": "openai/*",
                        "api_base": "https://api.sakana.ai/v1",
                        "api_key": "os.environ/SAKANA_API_KEY",
                    },
                    "model_info": {
                        "input_cost_per_token": 5e-06,
                        "output_cost_per_token": 3e-05,
                        "cache_read_input_token_cost": 5e-07,
                    },
                }
            ]
        ),
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
      # client-version.env carries the CODEX_CLIENT_VERSION genLitellmConfig
      # resolved (written before the container starts -- see the config service).
      environmentFiles = [ "/etc/litellm.env" "${configDir}/client-version.env" ];
      environment = {
        DATABASE_URL = "postgresql://litellm@127.0.0.1:5432/litellm";
        PYTHONPATH = "/config";
        CODEX_AUTH_FILE = "/root/.codex/auth.json";
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

  # LRU-evict old images (e.g. superseded litellm builds) once the image store
  # grows past the threshold. In-use images (the running container) are skipped.
  # docuum shells out to the `docker` CLI, so on this podman host give it a
  # docker->podman shim on PATH. docuum enumerates containers per Docker state
  # (`docker ps -a --filter status=<state>`), but podman rejects Docker-only
  # states like `dead`/`restarting`/`removing` ("unknown container state"). The
  # shim drops every `--filter status=*` pair, so podman just lists all
  # containers -- the same union docuum builds from the per-state queries.
  systemd.services.docuum = {
    description = "LRU eviction of old container images";
    wantedBy = [ "multi-user.target" ];
    after = [ "podman-litellm.service" ];
    path = [
      (pkgs.writeShellScriptBin "docker" ''
        remaining=$#
        while [ "$remaining" -gt 0 ]; do
          cur="$1"; shift; remaining=$((remaining - 1))
          if [ "$cur" = "--filter" ] && [ "$remaining" -gt 0 ]; then
            case "$1" in
              status=*) shift; remaining=$((remaining - 1)); continue ;;
            esac
          fi
          set -- "$@" "$cur"
        done
        exec ${pkgs.podman}/bin/podman "$@"
      '')
    ];
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
