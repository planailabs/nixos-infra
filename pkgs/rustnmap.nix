# rustnmap: the upstream network scanner CLI. GPL-3.0-or-later.
# Provides the `rustnmap` binary. (The project's REST API server — which the
# `remote` scan backend talks to — ships only as a crate example, not a bin,
# so it is not packaged here; run it from a checkout with
# `cargo run -p rustnmap-api --example server`.)
{ lib, rustPlatform, fetchFromGitHub, pkg-config, openssl }:

rustPlatform.buildRustPackage rec {
  pname = "rustnmap";
  version = "unstable-2026-07-15";

  src = fetchFromGitHub {
    owner = "greatwallisme";
    repo = "rustnmap";
    rev = "852ca1cc8e24ce5dd7d2cc19f9fab600981e00fb";
    hash = "sha256-fVYSXaTM3jisePTmnisUgr9QE7ZPlbgrzk29hOYx1zs=";
  };

  cargoHash = "sha256-Uyl+mq1Lomsbqw1Jrvt1d+I0T3jkwbOFpM8DLsCmqf4=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];

  # Link the CLI against system openssl (pcre2-sys/mlua still vendor their C).
  OPENSSL_NO_VENDOR = "1";

  # Build just the CLI bin, not the whole workspace (benchmarks, api, …).
  cargoBuildFlags = [ "--bin" "rustnmap" ];

  # Upstream's test suite hits the network / needs raw sockets.
  doCheck = false;

  meta = {
    description = "Async network scanner in Rust (nmap-like)";
    homepage = "https://github.com/greatwallisme/rustnmap";
    license = lib.licenses.gpl3Plus;
    mainProgram = "rustnmap";
  };
}
