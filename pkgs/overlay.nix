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
}
