{ stdenvNoCC, fetchurl, unzip, lib }:

stdenvNoCC.mkDerivation rec {
  pname = "obsidian-local-rest-api-plugin";
  version = "3.6.1";

  src = fetchurl {
    url = "https://github.com/coddingtonbear/obsidian-local-rest-api/releases/download/${version}/obsidian-local-rest-api-${version}.zip";
    hash = "sha256-ZrETCBEFDjHtQeRS3t0hFmMx24f4Wl1oDfaZKpelsqk=";
  };

  nativeBuildInputs = [ unzip ];

  unpackPhase = ''
    runHook preUnpack
    unzip $src
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp obsidian-local-rest-api/main.js obsidian-local-rest-api/manifest.json obsidian-local-rest-api/styles.css $out/
    runHook postInstall
  '';

  meta = with lib; {
    description = "Obsidian Local REST API community plugin (release artifacts)";
    homepage = "https://github.com/coddingtonbear/obsidian-local-rest-api";
    license = licenses.mit;
  };
}
