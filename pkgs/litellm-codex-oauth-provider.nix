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
  # Upstream has no tagged releases; _version.py reports 0.1.0. Pin the commit.
  version = "0.1.0-unstable-2025-12-11";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "jslorrma";
    repo = "litellm-codex-oauth-provider";
    rev = "4390c73f3e6a13e423cbc5633c8e35455f728ae9";
    hash = "sha256-977jP1uHooXv0tCUlak+CHvHY5YK0j2w8ke22Z20D3M=";
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
    description = "LiteLLM custom provider bridging Codex CLI OAuth to OpenAI-compatible APIs";
    homepage = "https://github.com/jslorrma/litellm-codex-oauth-provider";
    # Upstream ships no LICENSE file, so treat it as unfree (all rights reserved).
    license = lib.licenses.unfree;
  };
}
