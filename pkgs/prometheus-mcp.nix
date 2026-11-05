# The prometheus project's MCP server (github.com/prometheus/prometheus-mcp):
# the upstream release binary, statically linked Go.
{ stdenvNoCC, fetchzip, lib }:
stdenvNoCC.mkDerivation rec {
  pname = "prometheus-mcp";
  version = "0.18.0";
  src = fetchzip {
    url = "https://github.com/prometheus/prometheus-mcp/releases/download/v${version}/prometheus-mcp-server_${version}_linux_amd64.tar.gz";
    hash = "sha256-MBAd4i2JKbuvVza8X7wZ/kezTpLlWb4U3t2ptVkgrgk=";
    stripRoot = false;
  };
  installPhase = "install -Dm755 prometheus-mcp-server $out/bin/prometheus-mcp-server";
  meta = {
    description = "MCP server for LLMs to interact with Prometheus";
    homepage = "https://github.com/prometheus/prometheus-mcp";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "prometheus-mcp-server";
  };
}
