{ lib, python3Packages, fetchPypi }:

python3Packages.buildPythonApplication rec {
  pname = "cozempic";
  version = "1.8.9";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-ORxOjQPd5x1vooAssSA/5BcvZuhtZwW2wQKwDyqS8rE=";
  };

  build-system = [ python3Packages.setuptools ];

  pythonImportsCheck = [ "cozempic" ];

  meta = with lib; {
    description = "Context cleaning CLI for Claude Code — prune bloat, protect agent teams from compaction";
    homepage = "https://github.com/Ruya-AI/cozempic";
    changelog = "https://github.com/Ruya-AI/cozempic/releases/tag/v${version}";
    license = licenses.mit;
    mainProgram = "cozempic";
    platforms = platforms.all;
  };
}
