final: prev: {
  sanoid = prev.sanoid.overrideAttrs(_: {
    # patches = [ ./sanoid.patch ];
    src = prev.fetchFromGitHub {
      owner = "jimsalterjrs";
      repo = "sanoid";
      rev = "6beef5fee67deb2c17f160244953bd5a1983e1ad";
      sha256 = "sha256-uxfa6KIL0BfqmI/OzZjmOwXhte48SuEgL7eYp2DD/90=";
    };
  });

  obsidian-mcp-server = prev.callPackage ./obsidian-mcp-server { };
  obsidian-local-rest-api-plugin = prev.callPackage ./obsidian-local-rest-api-plugin.nix { };
  cozempic = prev.callPackage ./cozempic.nix { };
  prometheus-mcp = prev.callPackage ./prometheus-mcp.nix { };

  # nixpkgs' opencode 2.2.5 pins a node_modules hash its fetch no longer
  # yields (hash mismatch on every host since the 2026-11-05 nixpkgs). Only
  # while nixpkgs still carries that exact hash; its own fix takes over.
  opencode =
    if prev.opencode.version == "2.2.5" && prev.opencode.node_modules.outputHash == "sha256-xfOVcw1+waLVNhFDwzOtzxrUSQEogvn88YomydOlhwc="
    then prev.opencode.overrideAttrs (old: {
      node_modules = old.node_modules.overrideAttrs { outputHash = "sha256-prx9dX7kUvs/E3zopkaPk5LXh3xJAy5sZeum/W8L7cA="; };
    })
    else prev.opencode;

  # Codex OAuth custom provider (pure-Python source). The codex host mounts this
  # package's source into the official litellm container; litellm is provided by
  # the image, so the package treats it as a peer dependency (see the package).
  litellm-codex-oauth-provider = final.python3Packages.callPackage ./litellm-codex-oauth-provider.nix { };
} // prev.lib.optionalAttrs (prev ? xzar-server) {
  # xzar-server takes the upload's `drvFull` verbatim as the storage filename
  # (`server/src/storage.rs: file_path` joins it onto the storage root), so a
  # write token could name a path outside it — and the cleanup/GC delete uses
  # the same name. Upstream (mkg20001/xzar@dca77eb) has no fix and no newer
  # release; the patch refuses any name that is not one plain file name.
  xzar-server = prev.xzar-server.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./xzar-upload-path.patch ];

    # The lib's unit tests need neither postgres nor the client binary (only
    # the integration tests do), and they are where the storage-name check is
    # covered. Keep them running so a bad rebase of the patch is caught here.
    doCheck = true;
    cargoTestFlags = [ "-p" "xzar-server" "--lib" ];
  });
} // prev.lib.optionalAttrs (prev ? dioxus-cli-patched) {
  # dx aborts its own `cargo metadata` after ~200 s and fails the whole build
  # with "cargo metadata took too long to respond". This workspace's crates need
  # minutes for it on a loaded builder, so raise the bound to 30 min — the same
  # hunk mac-mgmt already carries. harbor and plan-ai-cloud do not yet, and their
  # server packages are what the logos/harbor systems install.
  #
  # Added only when the input's own patch lacks the hunk: mac-mgmt ships it, and
  # applying it twice fails with "Reversed (or previously applied) patch detected".
  dioxus-cli-patched = prev.dioxus-cli-patched.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ prev.lib.optional
      (!(prev.lib.any
        (p: builtins.match ".*for x in 1\\.\\.=900.*" (builtins.readFile p) != null)
        (old.patches or [ ])))
      ./dioxus-cli-metadata-timeout.patch;
  });
}
