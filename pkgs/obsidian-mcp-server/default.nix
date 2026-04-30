{ buildNpmPackage, fetchFromGitHub, nodejs_22, lib, makeWrapper }:

buildNpmPackage rec {
  pname = "obsidian-mcp-server";
  version = "3.1.1-014628e";

  src = fetchFromGitHub {
    owner = "planailabs";
    repo = "obsidian-mcp-server";
    rev = "014628e01d65021ebbcc55df7c30a3e4922acf7f";
    hash = "sha256-hnQU6F6W7Nq2CNXb5sKtfeZTXb0zvohhb8t8R25PN0Q=";
  };

  # Upstream ships a bun.lock; we vendor an npm-generated package-lock.json
  # so buildNpmPackage can use its standard fixed-output deps fetcher.
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-YyE272lc7pqqik1ni4YDy8cDetZSAPdHfGTTgvBoPNg=";

  nodejs = nodejs_22;

  nativeBuildInputs = [ makeWrapper ];

  # `npm run build` invokes scripts/build.ts via bun; we shim it to plain
  # tsc + tsc-alias so we don't need bun at build time.
  buildPhase = ''
    runHook preBuild
    ./node_modules/.bin/tsc -p tsconfig.build.json
    ./node_modules/.bin/tsc-alias -p tsconfig.build.json
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/obsidian-mcp-server
    cp -R dist node_modules package.json $out/lib/obsidian-mcp-server/

    mkdir -p $out/bin
    makeWrapper ${nodejs_22}/bin/node $out/bin/obsidian-mcp-server \
      --add-flags "$out/lib/obsidian-mcp-server/dist/index.js"

    runHook postInstall
  '';

  meta = with lib; {
    description = "MCP server for Obsidian vaults via the Local REST API plugin (planailabs fork, feat/read-only-env)";
    homepage = "https://github.com/planailabs/obsidian-mcp-server";
    license = licenses.asl20;
    mainProgram = "obsidian-mcp-server";
  };
}
