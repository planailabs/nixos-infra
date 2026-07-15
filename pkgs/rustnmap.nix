# rustnmap: the network scanner from the planailabs fork of
# greatwallisme/rustnmap. Provides two bins:
#   - rustnmap             — the CLI (upstream bin)
#   - rustnmap-api-server  — the REST API / daemon that the `remote` scan
#                            backend talks to. Upstream ships it only as a
#                            crate example (crates/rustnmap-api/examples/
#                            server.rs); the fork adds one commit declaring it
#                            as a [[bin]] so we can build it here. The server
#                            code is unchanged: it binds 127.0.0.1:8080 and
#                            logs auto-generated API keys at startup.
# GPL-3.0-or-later.
{ lib, rustPlatform, fetchFromGitHub, pkg-config, openssl }:

rustPlatform.buildRustPackage rec {
  pname = "rustnmap";
  version = "unstable-2026-07-15";

  # planailabs fork — same tree as upstream greatwallisme/rustnmap plus one
  # commit exposing the API server example as the rustnmap-api-server bin.
  src = fetchFromGitHub {
    owner = "planailabs";
    repo = "rustnmap";
    rev = "d799cb372c148551fa0709c8de20ccb818fc71f3";
    hash = "sha256-EzO7Nx++A/pgH1F/bbVJbRGpVh6Q3RvUBl1iCsolIOE=";
  };

  cargoHash = "sha256-Uyl+mq1Lomsbqw1Jrvt1d+I0T3jkwbOFpM8DLsCmqf4=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];

  # Link against system openssl (pcre2-sys/mlua still vendor their C).
  OPENSSL_NO_VENDOR = "1";

  # Build the two bins we ship, not the whole workspace (benchmarks, …).
  cargoBuildFlags = [ "--bin" "rustnmap" "--bin" "rustnmap-api-server" ];

  # Upstream's test suite hits the network / needs raw sockets.
  doCheck = false;

  meta = {
    description = "Async network scanner in Rust (nmap-like), with REST API server";
    homepage = "https://github.com/greatwallisme/rustnmap";
    license = lib.licenses.gpl3Plus;
    mainProgram = "rustnmap";
  };
}
