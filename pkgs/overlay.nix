final: prev:
let
  # litellm Python module with the proxy extras, matching how nixpkgs'
  # litellm/package.nix assembles the application. We reuse this both to build
  # the Codex provider plugin against the exact same litellm and to assemble the
  # bundled application below, guaranteeing a single litellm in the final env.
  py = final.python3Packages;
  litellmModule = py.litellm.overridePythonAttrs (old: {
    dependencies =
      (old.dependencies or [ ])
      ++ py.litellm.optional-dependencies.proxy
      ++ py.litellm.optional-dependencies.extra_proxy
      ++ py.litellm.optional-dependencies.proxy-runtime;
  });
in
{
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

  # Codex OAuth custom provider. It treats litellm as a peer dependency (see the
  # package), so it carries no litellm of its own and bundles cleanly below.
  litellm-codex-oauth-provider = py.callPackage ./litellm-codex-oauth-provider.nix { };

  # litellm proxy with the Codex OAuth provider importable from the same Python
  # environment, so `custom_provider_map` can reference
  # `litellm_codex_oauth_provider.codex_auth_provider`.
  litellm-with-codex = py.toPythonApplication (
    litellmModule.overridePythonAttrs (old: {
      dependencies = (old.dependencies or [ ]) ++ [ final.litellm-codex-oauth-provider ];
    })
  );
}
