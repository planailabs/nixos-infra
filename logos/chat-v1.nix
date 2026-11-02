# chat.plan.ai on the v1 chat (plan-ai/chat at tag v1: Astro, Supabase sign-in).
# The Rust chat moved to agent.plan.ai (logos/chat.nix). v1's own NixOS module
# declares services.plan-ai-chat too, so its unit is written out here; this is
# that module's service under another name and port.
{ inputs, pkgs, ... }:
let
  package = (inputs.plan-ai-chat-v1.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
    # Built into the browser bundle; the publishable key is public by design.
    envVars = {
      VITE_SUPABASE_URL = "https://tlssdiqdokctvxcezptr.supabase.co";
      VITE_SUPABASE_PUBLISHABLE_KEY = "sb_publishable_0jDsNegZ46CUSePRIj5-Bw_0_UYc41b";
    };
  }).overrideAttrs (old: {
    # The tag's hash is for the pnpm of its own nixpkgs; this one is for ours.
    # Update it when nixpkgs moves pnpm (the deploy says what it got).
    pnpmDeps = old.pnpmDeps.overrideAttrs (_: {
      outputHash = "sha256-QxRIn7fR5P5V7CpjZcfSvQ9x/qyNGjv/CwUlad2OOvM=";
    });
  });
in {
  systemd.services.plan-ai-chat-v1 = {
    description = "plan.ai chat (v1)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    # nginx: chat.plan.ai -> localhost:4322 (4321 is the Rust chat's).
    environment = {
      HOST = "127.0.0.1";
      PORT = "4322";
    };
    serviceConfig = {
      Type = "simple";
      ExecStart = pkgs.lib.getExe package;
      Restart = "on-failure";
      RestartSec = 5;
      # Supabase keys, Anthropic key, mac-mgmt URL: private/logos.nix.
      EnvironmentFile = "/etc/plan-ai-chat-v1.env";
      DynamicUser = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictNamespaces = true;
      RestrictSUIDSGID = true;
      MemoryDenyWriteExecute = false; # Node.js JIT needs this
    };
  };
}
