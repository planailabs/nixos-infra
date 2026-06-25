{ inputs, lib, pkgs, ... }: with lib;
let
  # Official litellm image with the database/proxy stack (prisma engines +
  # migrations) baked in. The nixpkgs litellm package can't do DB mode (no
  # litellm_proxy_extras, no generated prisma client), so for virtual keys /
  # spend tracking / the admin UI we run the upstream image instead. Pinned by
  # digest (ghcr.io/berriai/litellm-database:main-stable as of 2026-06-25).
  litellmImage = "ghcr.io/berriai/litellm-database@sha256:2dc76c3e37a0c4eecc5c7c08e26c8923938fb1e8e7ff860074025373dc3ce3c6";

  litellmSettings = {
    general_settings.master_key = "os.environ/LITELLM_MASTER_KEY";

    # ChatGPT Plus via Codex OAuth. These are OpenAI's latest GPT-5.1 Codex
    # models, served through the user's ChatGPT plan (no API key -- the
    # provider uses /root/.codex/auth.json from `codex login`, run on the host).
    model_list = [
      { model_name = "chatgpt-plus-gpt-5.1-codex-max"; litellm_params.model = "codex/gpt-5.1-codex-max"; }
      { model_name = "chatgpt-plus-gpt-5.1-codex"; litellm_params.model = "codex/gpt-5.1-codex"; }
      { model_name = "chatgpt-plus-gpt-5.1-codex-mini"; litellm_params.model = "codex/gpt-5.1-codex-mini"; }
      { model_name = "chatgpt-plus-gpt-5.1"; litellm_params.model = "codex/gpt-5.1"; }
    ];

    litellm_settings.custom_provider_map = [
      { provider = "codex"; custom_handler = "codex_handler.codex_auth_provider"; }
    ];
  };

  # The codex model names overlap with OpenAI's (gpt-5.1*), which are in
  # litellm.open_ai_chat_completion_models. litellm's completion dispatch routes
  # any model in that list to its built-in OpenAI handler BEFORE it checks the
  # custom-provider map -- so without intervention our "codex/gpt-5.1-*" calls go
  # to OpenAI (and fail: no api key) instead of our provider. The handler shim
  # drops these names from that list at import (config-load time, before any
  # request) so dispatch falls through to the custom provider.
  codexModels = map (m: lib.removePrefix "codex/" m.litellm_params.model) litellmSettings.model_list;
  codexHandlerPy = ''
    import litellm
    for _m in [${lib.concatMapStringsSep ", " (m: "\"${m}\"") codexModels}]:
        while _m in litellm.open_ai_chat_completion_models:
            litellm.open_ai_chat_completion_models.remove(_m)
    from litellm_codex_oauth_provider import codex_auth_provider
  '';

  # Bind-mounted into the container at /config. Contains:
  #  - config.yaml
  #  - codex_handler.py: litellm resolves `custom_handler` as a file RELATIVE to
  #    the config dir (not as an installed module), so this shim re-exports the
  #    provider instance (and applies the dispatch fix above).
  #  - litellm_codex_oauth_provider/: the provider package source, importable via
  #    PYTHONPATH=/config. It's pure Python; its runtime deps (litellm, httpx,
  #    openai, typing_extensions) are already in the image.
  litellmConfigDir = pkgs.runCommand "litellm-codex-config" { } ''
    mkdir -p "$out"
    cp ${(pkgs.formats.yaml { }).generate "config.yaml" litellmSettings} "$out/config.yaml"
    cp ${pkgs.writeText "codex_handler.py" codexHandlerPy} "$out/codex_handler.py"
    cp -r ${pkgs.litellm-codex-oauth-provider}/lib/python*/site-packages/litellm_codex_oauth_provider "$out/"
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
        SCARF_NO_ANALYTICS = "True";
        DO_NOT_TRACK = "True";
        ANONYMIZED_TELEMETRY = "False";
      };
      volumes = [
        "${litellmConfigDir}:/config:ro"
        # The provider reads and (on refresh) rewrites the Codex tokens here;
        # `codex login` on the host populates it. Mounted rw so refresh persists.
        "/root/.codex:/root/.codex:rw"
      ];
    };
  };

  # The container needs Postgres up first (migrations run on start).
  systemd.services.podman-litellm = {
    after = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];
  };

  # `codex login` on the host writes /root/.codex/auth.json (mounted into the
  # container); the provider reads and refreshes it in place.
  environment.systemPackages = [ pkgs.codex ];

  security.acme.distributor-server = "https://acme.plan.ai";

  networking.hostName = "codex";
}
