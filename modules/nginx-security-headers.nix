# Transport, framing and metadata headers for every vhost this host serves.
#
# These sit in the http block so each virtualHost inherits them. nginx drops the
# inherited set for a location that defines its own add_header, which is why
# framing is expressed as a CSP rather than X-Frame-Options: duplicate CSP
# policies are intersected by the browser, duplicate X-Frame-Options headers are
# not (browsers disagree on which one wins), and several apps behind this proxy
# already send their own.
{ config, lib, ... }:

let
  headers = ''
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains" always;
    add_header X-Content-Type-Options nosniff always;
    add_header Referrer-Policy strict-origin-when-cross-origin always;
    add_header Content-Security-Policy "frame-ancestors 'none'" always;
  '';
in
{
  services.nginx.commonHttpConfig = headers;

  # The oauth2-proxy module adds `add_header Set-Cookie` to the protected
  # vhosts' `/`, which would drop the inherited set on exactly the hosts that
  # matter most (auth, prometheus, memvault, wiki). Re-add it at that level.
  services.nginx.virtualHosts = lib.mapAttrs (_: _: {
    locations."/".extraConfig = lib.mkAfter headers;
  }) config.services.oauth2-proxy.nginx.virtualHosts;
}
