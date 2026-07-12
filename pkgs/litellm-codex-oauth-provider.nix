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
  # Fork of jslorrma/litellm-codex-oauth-provider: implements OAuth access-token
  # refresh and live model discovery (upstream stubs refresh and hard-codes stale
  # model names). No tagged releases, so pin the commit.
  version = "0.3.1-unstable-2026-07-13";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "mkg20001";
    repo = "litellm-codex-oauth-provider";
    rev = "b092096f46a8b098dc677f760caaa27584c34b00";
    hash = "sha256-uYUe7TZNyJh/yw2zqL4elc3fg7WgWwZWBynJAV+WNPY=";
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
