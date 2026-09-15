{ inputs, lib, pkgs, ... }:

with lib;

let
  hip = inputs.hippocampus.packages.x86_64-linux;

  # hippocampus is deliberately NOT follows-ed onto our nixpkgs (see flake.nix),
  # so reach into the nixpkgs it pins for the model stack. Mixing python sets
  # from two nixpkgs instances does not work, so everything that goes into the
  # generator below comes from this one.
  hipPkgs = inputs.hippocampus.inputs.nixpkgs.legacyPackages.x86_64-linux;

  # The upstream `hippocampus-generator` package builds torch with
  # cudaSupport. This host is an LXC container with no GPU, where that closure
  # is both useless and unbuildable -- it would have to compile magma, triton
  # and nccl locally. The generating backend is the same application as the
  # frontend plus the model stack, which is exactly what the `generator` extra
  # adds, so add the CPU build of it instead; all of that substitutes.
  hippocampus-generator-cpu = hip.hippocampus.overridePythonAttrs (old: {
    pname = "hippocampus-generator-cpu";
    dependencies = old.dependencies ++ (with hipPkgs.python3.pkgs; [
      accelerate
      torch
      transformers
    ]);
    meta = old.meta // { mainProgram = "hippocampus-generate-server"; };
  });

  # One store, shared by both halves. Served by the local garage; see
  # ./garage.nix, and private/hippocampus.nix for the keys.
  store = {
    bucket = "hippocampus";
    endpoint = "http://127.0.0.1:3900";
    region = "garage";
    environmentFile = "/etc/hippocampus.env";
  };
in
{
  imports = [
    ../modules/common.nix
    ../modules/container.nix
    "${inputs.self.private}/hippocampus.nix"
    ./nginx.nix
    ./garage.nix
  ];

  system.stateVersion = "26.11";

  nixpkgs.hostPlatform = "x86_64-linux";

  networking.hostName = "hippocampus";

  # The additional Hetzner IPv4, on a macvlan NIC bound to the virtual MAC
  # Hetzner assigned to it (set on the incus device, not here). Routed rather
  # than on-link, hence the /26 with an explicit peer -- same shape as logos.
  # Without it this container is IPv6-only: atlas has one IPv4 and no DNAT, so
  # anything that resolves only A records (Claude's MCP connector, for one)
  # cannot reach it at all.
  systemd.network = {
    networks."40-public0" = {
      matchConfig = {
        Name = "public0";
      };
      gateway = [ "65.108.140.193" ];
      addresses = [
        { Address = "65.108.140.198/26"; Peer = "65.108.140.193"; }
      ];
    };
  };

  mkg.mod = {
    yggdrasil = {
      enable = true;
      port = 14466;
      peers = [ "tcp://ygg.mkg20001.io:80" "tls://ygg.mkg20001.io:443" ];
    };
  };

  security.acme.distributor-server = "https://acme.plan.ai";

  # The user-facing backend: accounts, sessions, quotas, datasets. No torch.
  services.hippocampus.frontend = {
    enable = true;
    package = hip.hippocampus;
    host = "127.0.0.1";
    port = 8080;
    publicUrl = "https://hippocampus.plan.ai";
    inherit store;
    environment = {
      OIDC_PROVIDERS = "google";
      OIDC_GOOGLE_ISSUER = "https://accounts.google.com";
      OIDC_GOOGLE_CLIENT_ID = "70647020296-l53ldtd0m0loi1n0llr9kg3f76as1fmg.apps.googleusercontent.com";
      OIDC_GOOGLE_LABEL = "Google";
      # Sign-in is open to any Google account (the app has no domain filter),
      # and without this the FIRST account to arrive would be handed admin.
      # Naming the admins closes that: everyone else lands as a plain user.
      ADMIN_EMAILS = "maciej@plan.ai";
      # Document extraction and question answering both call one
      # OpenAI-compatible chat/completions endpoint; DeepSeek serves that
      # shape, so no gateway in between. No /v1 on the base URL: the app
      # appends it unless the URL already ends in /v1. OPENAI_API_KEY is the
      # secret half and lives in private/hippocampus.nix, which the same
      # EnvironmentFile carries. OPENAI_REASONING_EFFORT is left unset:
      # extraction already defaults it to "low" and questions send none.
      OPENAI_BASE_URL = "https://api.deepseek.com";
      OPENAI_MODEL = "deepseek-flash";
    };
  };

  # The generating backend, on CPU. Slow by construction -- this is a
  # container, not a GPU host -- so it serves the 1.7B adapter only; the 8B and
  # 9B Qwen adapters want a card. A GPU generator elsewhere can register
  # against the same frontend and will simply be preferred for its own models.
  services.hippocampus.generator = {
    enable = true;
    package = hippocampus-generator-cpu;
    adapters = [ "${hip.datasets}/data/artifacts/smollm2-1.7b-adapter.pt" ];
    deviceMap = "cpu";
    host = "127.0.0.1";
    port = 8100;
    # Both halves are on this host, so register over loopback: no dependency on
    # DNS, TLS or the public vhost being up before the generator can announce.
    frontend = "http://127.0.0.1:8080";
    url = "http://127.0.0.1:8100";
    inherit store;
  };

  systemd.services.hippocampus-frontend = {
    after = [ "garage-hippocampus-init.service" ];
    requires = [ "garage-hippocampus-init.service" ];
  };

  systemd.services.hippocampus-generator = {
    after = [ "garage-hippocampus-init.service" "hippocampus-frontend.service" ];
    requires = [ "garage-hippocampus-init.service" ];
    wants = [ "hippocampus-frontend.service" ];
  };

  # Put the graphs that ship with the repo into the store, so a fresh install
  # has something in the picker. Storage-only on purpose: the ownership rows
  # live in the frontend's sessions.db under its DynamicUser, and a dataset
  # with no row is public -- which is what these are.
  systemd.services.hippocampus-seed = {
    description = "Import the bundled hippocampus graphs into the dataset store";
    after = [ "garage-hippocampus-init.service" ];
    requires = [ "garage-hippocampus-init.service" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      S3_BUCKET = store.bucket;
      S3_ENDPOINT = store.endpoint;
      S3_REGION = store.region;
      S3_ADDRESSING = "path";
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      EnvironmentFile = store.environmentFile;
    };
    script = let
      # --sessions names a database that deliberately does not exist: without
      # it the CLI is storage-only, which is all the seeding needs.
      datasets = "${getExe' hip.hippocampus "hippocampus-datasets"} --env /dev/null --sessions /var/empty/no-registry";
    in ''
      set -eu
      # Only ever seeds an empty store: anything imported or extracted later
      # means this has already run, and a deleted dataset stays deleted.
      if [ "$(${datasets} list)" = "[]" ]; then
        ${datasets} import ${hip.datasets}/data/datasets/examples.json \
          --as examples --title "Examples" \
          --description "The worked examples that ship with hippocampus."
        ${datasets} import ${hip.datasets}/data/datasets/scientific_vijay2021.json \
          --as scientific-vijay2021 --title "Scientific (Vijay 2021)" \
          --description "Extracted scientific corpus that ships with hippocampus."
      fi
    '';
  };
}
