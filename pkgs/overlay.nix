final: prev: {
  sanoid = prev.sanoid.overrideAttrs(_: {
    # patches = [ ./sanoid.patch ];
    src = prev.fetchFromGitHub {
      owner = "jimsalterjrs";
      repo = "sanoid";
      rev = "6beef5fee67deb2c17f160244953bd5a1983e1ad";
      sha256 = "sha256-uxfa6KIL0BfqmI/OzZjmOwXhte48SuEgL7eYp2DD/90=";
    };
  });
}
