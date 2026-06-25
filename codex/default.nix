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
      # The provider reads Codex CLI OAuth tokens from this file. litellm runs as
      # a DynamicUser with ProtectHome, so there is no ~/.codex; point it at the
      # systemd credential loaded below (%d = $CREDENTIALS_DIRECTORY).
      CODEX_AUTH_FILE = "%d/codex-auth";
    };

    settings = {
      general_settings.master_key = "os.environ/LITELLM_MASTER_KEY";

      # ChatGPT Plus via Codex OAuth. These are OpenAI's latest GPT-5.1 Codex
      # models, served through the user's ChatGPT plan (no API key -- the
      # provider uses the Codex auth.json loaded as a credential below).
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

  # Load the Codex auth.json (produced by `codex login`) as a systemd credential.
  # LoadCredential reads it as root and exposes it read-only in the service's
  # private credentials dir, which works with DynamicUser. Refreshing the token
  # is a manual `codex login` + redeploy of the secret — upstream has not yet
  # implemented automatic refresh.
  systemd.services.litellm.serviceConfig.LoadCredential = [
    "codex-auth:/etc/codex-auth.json"
  ];

  security.acme.distributor-server = "https://acme.plan.ai";

  networking.hostName = "codex";
}
