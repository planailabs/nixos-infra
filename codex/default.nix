{ inputs, lib, pkgs, ... }: with lib; {
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

  services.litellm = {
    enable = true;
    # litellm with the Codex OAuth custom provider on its Python path.
    package = pkgs.litellm-with-codex;
    host = "127.0.0.1";
    port = 8080;
    # Provides LITELLM_MASTER_KEY (and any provider API keys) out of the Nix store.
    environmentFile = "/etc/litellm.env";
    environment = {
      SCARF_NO_ANALYTICS = "True";
      DO_NOT_TRACK = "True";
      ANONYMIZED_TELEMETRY = "False";
      # The provider reads -- and, on refresh, rewrites -- the Codex OAuth tokens
      # here. It must be a writable path (the fork persists rotated tokens), so
      # we use root's home rather than a read-only systemd credential.
      CODEX_AUTH_FILE = "/root/.codex/auth.json";
    };

    settings = {
      general_settings.master_key = "os.environ/LITELLM_MASTER_KEY";

      # ChatGPT Plus via Codex OAuth. These are OpenAI's latest GPT-5.1 Codex
      # models, served through the user's ChatGPT plan (no API key -- the
      # provider uses /root/.codex/auth.json from `codex login`, run on the host).
      model_list = [
        {
          model_name = "chatgpt-plus-gpt-5.1-codex-max";
          litellm_params.model = "codex/gpt-5.1-codex-max";
        }
        {
          model_name = "chatgpt-plus-gpt-5.1-codex";
          litellm_params.model = "codex/gpt-5.1-codex";
        }
        {
          model_name = "chatgpt-plus-gpt-5.1-codex-mini";
          litellm_params.model = "codex/gpt-5.1-codex-mini";
        }
        {
          model_name = "chatgpt-plus-gpt-5.1";
          litellm_params.model = "codex/gpt-5.1";
        }
      ];

      litellm_settings.custom_provider_map = [
        {
          provider = "codex";
          custom_handler = "litellm_codex_oauth_provider.provider.codex_auth_provider";
        }
      ];
    };
  };

  # Authenticate the proxy by running `codex login` on the host (the Codex CLI
  # is in systemPackages below); it writes /root/.codex/auth.json, which the
  # provider then reads and refreshes in place.
  environment.systemPackages = [ pkgs.codex ];

  # The provider rewrites auth.json on token refresh, so litellm needs write
  # access to /root/.codex. Drop the module's DynamicUser sandbox and run as
  # root with its home reachable.
  systemd.services.litellm.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = lib.mkForce "root";
    Group = lib.mkForce "root";
    ProtectHome = lib.mkForce false;
    PrivateUsers = lib.mkForce false;
  };

  security.acme.distributor-server = "https://acme.plan.ai";

  networking.hostName = "codex";
}
