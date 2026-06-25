{ lib
, buildPythonPackage
, fetchFromGitHub
, hatchling
, httpx
, typing-extensions
, openai
}:

buildPythonPackage {
  pname = "litellm-codex-oauth-provider";
  # Fork of jslorrma/litellm-codex-oauth-provider that implements OAuth access
  # token refresh (upstream only stubs it). No tagged releases, so pin the commit.
  version = "0.2.0-unstable-2026-06-25";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "mkg20001";
    repo = "litellm-codex-oauth-provider";
    rev = "925bbf578dd1221fa981f19a02bb1fbe5dcaf82f";
    hash = "sha256-NUgnb6+BTIgNRoGtXbo//7T5PxEE/hUbJFipyAjfZMo=";
  };

  build-system = [ hatchling ];

  # litellm is a *peer* dependency: this package is only ever bundled into a
  # litellm install (see pkgs/overlay.nix `litellm-with-codex`), which already
  # provides it. Propagating our own litellm here would put a second, distinct
  # litellm derivation in that environment and trip pythonCatchConflictsPhase.
  dependencies = [
    httpx
    typing-extensions
    openai
  ];

  # The wheel's metadata still declares litellm as a runtime dependency; drop it
  # so pythonRuntimeDepsCheckHook doesn't demand a (duplicate) litellm here. The
  # bundling litellm install satisfies it at runtime.
  pythonRemoveDeps = [ "litellm" ];

  # The test suite is driven by pixi and reaches the live ChatGPT backend.
  doCheck = false;

  # No pythonImportsCheck: importing the package pulls in litellm, which is the
  # peer dependency this package deliberately omits. The import is exercised
  # against the bundled environment instead (pkgs/overlay.nix `litellm-with-codex`).

  meta = {
    description = "LiteLLM custom provider bridging Codex CLI OAuth to OpenAI-compatible APIs (fork with token refresh)";
    homepage = "https://github.com/mkg20001/litellm-codex-oauth-provider";
    # Upstream ships no LICENSE file, so treat it as unfree (all rights reserved).
    license = lib.licenses.unfree;
  };
}
