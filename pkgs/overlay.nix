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
  rustnmap = prev.callPackage ./rustnmap.nix { };

  # Codex OAuth custom provider (pure-Python source). The codex host mounts this
  # package's source into the official litellm container; litellm is provided by
  # the image, so the package treats it as a peer dependency (see the package).
  litellm-codex-oauth-provider = final.python3Packages.callPackage ./litellm-codex-oauth-provider.nix { };
}
