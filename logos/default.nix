{ inputs, lib, pkgs, ... }: with lib; {
  imports = [
    ../modules/common.nix
    ../modules/container.nix
    "${inputs.self.private}/logos.nix"
    ./nginx.nix
    ./hedgedoc.nix
    ./zitadel.nix
  ];

  system.stateVersion = "26.11";

  nixpkgs.hostPlatform = "x86_64-linux";

  systemd.network = {
    networks."40-public0" = {
      matchConfig = {
        Name = "public0";
      };
      gateway = [ "65.108.140.193" ];
      addresses = [
        { Address = "65.108.140.230/26"; Peer = "65.108.140.193"; }
      ];
    };
  };

  mkg.mod = {
    yggdrasil = {
      enable = true;
      port = 14466;
      peers = [ "tcp://ygg.mkg20001.io:80" "tls://ygg.mkg20001.io:443" ];
    };
  };

  services.grafana = {
    enable = true;
    settings = {
      feature_toggles.publicDashboards = true;
      server = {
        http_addr = "127.0.0.1";
        http_port = 3434;
        root_url = "https://grafana.plan.ai";
      };
    };
  };

  services.prometheus = {
    enable = true;
    port = 9090;
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = lib.mapAttrsToList
          (name: ip: {
            targets = [ "[${ip}]:9100" ];
            labels.hostname = name;
          })
          (import ../modules/yggdrasil-ips.nix);
      }
    ];
    rules = [
      ''
        groups:
          - name: disk
            rules:
              - alert: NodeFilesystemLowSpace
                expr: (node_filesystem_avail_bytes{fstype!~"tmpfs|fuse.*|overlay|squashfs|ramfs"} / node_filesystem_size_bytes) * 100 < 10
                for: 10m
                labels:
                  severity: warning
                annotations:
                  summary: "Low disk space on {{ $labels.instance }} ({{ $labels.mountpoint }})"
                  description: "Filesystem {{ $labels.mountpoint }} on {{ $labels.instance }} has less than 10% free space (currently {{ $value | printf \"%.1f\" }}%)."
              - alert: NodeFilesystemCriticalSpace
                expr: (node_filesystem_avail_bytes{fstype!~"tmpfs|fuse.*|overlay|squashfs|ramfs"} / node_filesystem_size_bytes) * 100 < 5
                for: 5m
                labels:
                  severity: critical
                annotations:
                  summary: "Critically low disk space on {{ $labels.instance }} ({{ $labels.mountpoint }})"
                  description: "Filesystem {{ $labels.mountpoint }} on {{ $labels.instance }} has less than 5% free space (currently {{ $value | printf \"%.1f\" }}%)."
          - name: scrape
            rules:
              - alert: PrometheusTargetDown
                expr: up == 0
                for: 5m
                labels:
                  severity: critical
                annotations:
                  summary: "Prometheus failing to fetch from {{ $labels.job }} on {{ $labels.instance }}"
                  description: "Prometheus has been unable to scrape job {{ $labels.job }} on {{ $labels.instance }} for more than 5 minutes."
          - name: memory
            rules:
              - alert: NodeMemoryHigh
                expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
                for: 10m
                labels:
                  severity: warning
                annotations:
                  summary: "High RAM usage on {{ $labels.hostname }} ({{ $labels.instance }})"
                  description: "Memory usage on {{ $labels.hostname }} has been above 85% for more than 10 minutes (currently {{ $value | printf \"%.1f\" }}%)."
              - alert: NodeMemoryCritical
                expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 95
                for: 5m
                labels:
                  severity: critical
                annotations:
                  summary: "Critical RAM usage on {{ $labels.hostname }} ({{ $labels.instance }})"
                  description: "Memory usage on {{ $labels.hostname }} has been above 95% for more than 5 minutes (currently {{ $value | printf \"%.1f\" }}%)."
          - name: mac-mgmt-relay
            rules:
              - alert: MacMgmtHeartbeatStale
                expr: time() - mac_mgmt_heartbeat_last_success_timestamp_seconds > 600
                for: 5m
                labels:
                  severity: critical
                annotations:
                  summary: "mac-mgmt heartbeat stale on {{ $labels.hostname }}"
                  description: "No successful heartbeat from {{ $labels.hostname }} ({{ $labels.cluster_name }}) for {{ $value | printf \"%.0f\" }}s -- daemon likely offline."
              - alert: MacMgmtHeartbeatFailing
                expr: rate(mac_mgmt_heartbeat_total{result="failure"}[10m]) > 0
                for: 15m
                labels:
                  severity: warning
                annotations:
                  summary: "mac-mgmt heartbeat failures on {{ $labels.hostname }}"
                  description: "Heartbeat failures observed on {{ $labels.hostname }} ({{ $labels.cluster_name }}) for over 15 minutes."
              - alert: MacMgmtRelayScrapeDown
                expr: mac_mgmt_relay_scrape_up == 0
                for: 10m
                labels:
                  severity: critical
                annotations:
                  summary: "Relay scrape failing for {{ $labels.hostname }}"
                  description: "Relay has been unable to scrape {{ $labels.hostname }} ({{ $labels.cluster_id }}) for more than 10 minutes."
              - alert: MacMgmtRelayScrapeTimeout
                expr: mac_mgmt_relay_scrape_duration_seconds >= 5
                for: 15m
                labels:
                  severity: warning
                annotations:
                  summary: "Relay scrape timing out for {{ $labels.hostname }}"
                  description: "Relay scrape of {{ $labels.hostname }} ({{ $labels.cluster_id }}) has been hitting the 5s timeout for over 15 minutes."
              - alert: MacMgmtRelayNoTargets
                expr: mac_mgmt_relay_scrape_targets == 0
                for: 10m
                labels:
                  severity: critical
                annotations:
                  summary: "Relay has zero scrape targets"
                  description: "mac_mgmt_relay_scrape_targets has been 0 for more than 10 minutes -- discovery may be broken."
          - name: mac-mgmt-host
            rules:
              - alert: MacMgmtThermalCritical
                expr: mac_mgmt_thermal_state{state="critical"} > 0
                for: 5m
                labels:
                  severity: critical
                annotations:
                  summary: "Critical thermal state on {{ $labels.hostname }}"
                  description: "{{ $labels.hostname }} ({{ $labels.cluster_name }}) has reported thermal state=critical for over 5 minutes."
              - alert: MacMgmtThermalSerious
                expr: mac_mgmt_thermal_state{state="serious"} > 0
                for: 10m
                labels:
                  severity: warning
                annotations:
                  summary: "Serious thermal state on {{ $labels.hostname }}"
                  description: "{{ $labels.hostname }} ({{ $labels.cluster_name }}) has reported thermal state=serious for over 10 minutes."
              - alert: MacMgmtGpuTemperatureHigh
                expr: mac_mgmt_gpu_temperature_celsius > 85
                for: 10m
                labels:
                  severity: warning
                annotations:
                  summary: "High GPU temperature on {{ $labels.hostname }} (gpu {{ $labels.index }})"
                  description: "GPU {{ $labels.index }} on {{ $labels.hostname }} has been above 85C for more than 10 minutes (currently {{ $value }}C)."
              - alert: MacMgmtGpuTemperatureCritical
                expr: mac_mgmt_gpu_temperature_celsius > 95
                for: 5m
                labels:
                  severity: critical
                annotations:
                  summary: "Critical GPU temperature on {{ $labels.hostname }} (gpu {{ $labels.index }})"
                  description: "GPU {{ $labels.index }} on {{ $labels.hostname }} has been above 95C for more than 5 minutes (currently {{ $value }}C)."
              - alert: MacMgmtCpuLoadHigh
                expr: mac_mgmt_cpu_load_1m / mac_mgmt_cpu_cores_logical > 2
                for: 15m
                labels:
                  severity: warning
                annotations:
                  summary: "Sustained CPU overload on {{ $labels.hostname }}"
                  description: "1m load on {{ $labels.hostname }} ({{ $labels.cluster_name }}) has been above 2x logical core count for more than 15 minutes (currently {{ $value | printf \"%.2f\" }}x)."
              - alert: MacMgmtDiskFreeLow
                expr: mac_mgmt_disk_free_bytes / mac_mgmt_disk_total_bytes < 0.1
                for: 15m
                labels:
                  severity: warning
                annotations:
                  summary: "Low disk space on {{ $labels.hostname }} ({{ $labels.mount }})"
                  description: "Mount {{ $labels.mount }} on {{ $labels.hostname }} has less than 10% free for more than 15 minutes (currently {{ $value | printf \"%.1f\" }}%)."
              - alert: MacMgmtDiskFreeCritical
                expr: mac_mgmt_disk_free_bytes / mac_mgmt_disk_total_bytes < 0.05
                for: 5m
                labels:
                  severity: critical
                annotations:
                  summary: "Critically low disk space on {{ $labels.hostname }} ({{ $labels.mount }})"
                  description: "Mount {{ $labels.mount }} on {{ $labels.hostname }} has less than 5% free for more than 5 minutes (currently {{ $value | printf \"%.1f\" }}%)."
              - alert: MacMgmtMemoryHigh
                expr: mac_mgmt_mem_used_bytes / mac_mgmt_mem_total_bytes > 0.9
                for: 15m
                labels:
                  severity: warning
                annotations:
                  summary: "High memory usage on {{ $labels.hostname }}"
                  description: "Memory usage on {{ $labels.hostname }} ({{ $labels.cluster_name }}) has been above 90% for more than 15 minutes (currently {{ $value | printf \"%.1f\" }}%)."
          - name: mac-mgmt-services
            rules:
              - alert: MacMgmtServiceUnhealthy
                expr: mac_mgmt_service_healthy == 0
                for: 5m
                labels:
                  severity: critical
                annotations:
                  summary: "mac-mgmt service {{ $labels.service }} unhealthy on {{ $labels.hostname }}"
                  description: "mac_mgmt_service_healthy for service={{ $labels.service }} on {{ $labels.hostname }} ({{ $labels.cluster_name }}) has been 0 for more than 5 minutes."
              - alert: MacMgmtProbeNotOk
                expr: mac_mgmt_probe_ok == 0
                for: 5m
                labels:
                  severity: critical
                annotations:
                  summary: "mac-mgmt probe {{ $labels.kind }}/{{ $labels.service }} failing on {{ $labels.hostname }}"
                  description: "mac_mgmt_probe_ok for service={{ $labels.service }} kind={{ $labels.kind }} on {{ $labels.hostname }} ({{ $labels.cluster_name }}) has been 0 for more than 5 minutes."
              - alert: MacMgmtProbeStale
                expr: time() - mac_mgmt_probe_last_run_timestamp_seconds > 1800
                for: 10m
                labels:
                  severity: warning
                annotations:
                  summary: "mac-mgmt probe stale for {{ $labels.service }} on {{ $labels.hostname }}"
                  description: "Probe for service={{ $labels.service }} on {{ $labels.hostname }} has not run for {{ $value | printf \"%.0f\" }}s."
              - alert: MacMgmtProbeFirstTokenSlow
                expr: mac_mgmt_probe_first_token_ms > 10000
                for: 30m
                labels:
                  severity: warning
                annotations:
                  summary: "Slow first token for {{ $labels.service }} on {{ $labels.hostname }}"
                  description: "Probe first token for service={{ $labels.service }} on {{ $labels.hostname }} has been above 10s for more than 30 minutes (currently {{ $value | printf \"%.0f\" }}ms)."
              - alert: MacMgmtProbeDurationSlow
                expr: mac_mgmt_probe_duration_ms > 60000
                for: 30m
                labels:
                  severity: warning
                annotations:
                  summary: "Slow probe duration for {{ $labels.service }} on {{ $labels.hostname }}"
                  description: "Probe duration for service={{ $labels.service }} on {{ $labels.hostname }} has been above 60s for more than 30 minutes (currently {{ $value | printf \"%.0f\" }}ms)."
              - alert: MacMgmtUpgradePendingLong
                expr: mac_mgmt_service_upgrade_pending == 1
                for: 24h
                labels:
                  severity: warning
                annotations:
                  summary: "Pending upgrade not applied: {{ $labels.service }} on {{ $labels.hostname }}"
                  description: "Service {{ $labels.service }} on {{ $labels.hostname }} ({{ $labels.cluster_name }}) has had an upgrade pending for more than 24 hours."
          - name: web-agency-webspace
            rules:
              - alert: WebAgencyWebspaceNotRunning
                expr: web_agency_webspace_running == 0
                for: 10m
                labels:
                  severity: warning
                annotations:
                  summary: "Webspace {{ $labels.webspace }} ({{ $labels.org }}) not running"
                  description: "Webspace {{ $labels.webspace }} for org {{ $labels.org }} (hosting_type={{ $labels.hosting_type }}) has had local_status != running for more than 10 minutes."
              - alert: WebAgencyReachabilityHttpDown
                expr: web_agency_reachability_http_ok == 0
                for: 10m
                labels:
                  severity: critical
                annotations:
                  summary: "HTTP unreachable: {{ $labels.hostname }} ({{ $labels.org }}/{{ $labels.webspace }})"
                  description: "Reachability HTTP check has failed for {{ $labels.hostname }} (webspace {{ $labels.webspace }}, org {{ $labels.org }}) for more than 10 minutes."
              - alert: WebAgencyReachabilitySslDown
                expr: web_agency_reachability_ssl_ok == 0
                for: 15m
                labels:
                  severity: critical
                annotations:
                  summary: "SSL check failing: {{ $labels.hostname }} ({{ $labels.org }}/{{ $labels.webspace }})"
                  description: "Reachability SSL check has failed for {{ $labels.hostname }} (webspace {{ $labels.webspace }}, org {{ $labels.org }}) for more than 15 minutes."
              - alert: WebAgencyReachabilityProxyDown
                expr: web_agency_reachability_proxy_ok == 0
                for: 10m
                labels:
                  severity: critical
                annotations:
                  summary: "Proxy check failing: {{ $labels.hostname }} ({{ $labels.org }}/{{ $labels.webspace }})"
                  description: "Reachability proxy check has failed for {{ $labels.hostname }} (webspace {{ $labels.webspace }}, org {{ $labels.org }}) for more than 10 minutes."
              - alert: WebAgencyReachabilityHighLatency
                expr: web_agency_reachability_latency_ms > 5000
                for: 15m
                labels:
                  severity: warning
                annotations:
                  summary: "High latency to {{ $labels.hostname }} ({{ $labels.org }}/{{ $labels.webspace }})"
                  description: "Reachability latency for {{ $labels.hostname }} (webspace {{ $labels.webspace }}, org {{ $labels.org }}) has been above 5000ms for more than 15 minutes (currently {{ $value | printf \"%.0f\" }}ms)."
              - alert: WebAgencyReachabilityStale
                expr: time() - web_agency_reachability_checked_at > 3600
                for: 10m
                labels:
                  severity: warning
                annotations:
                  summary: "Reachability check stale for {{ $labels.hostname }} ({{ $labels.org }}/{{ $labels.webspace }})"
                  description: "No reachability check has run for {{ $labels.hostname }} (webspace {{ $labels.webspace }}, org {{ $labels.org }}) in over an hour (last checked {{ $value | printf \"%.0f\" }}s ago)."
          - name: web-agency-relay
            rules:
              - alert: WebAgencyRelayTokenMintFailing
                expr: web_agency_relay_token_mint_ok == 0
                for: 10m
                labels:
                  severity: critical
                annotations:
                  summary: "Relay token mint failing for {{ $labels.hostname }} ({{ $labels.org }})"
                  description: "Last relay token mint has failed for hostname {{ $labels.hostname }} (org {{ $labels.org }}) for more than 10 minutes."
              - alert: WebAgencyRelayTokenMintErrorRate
                expr: rate(web_agency_relay_token_mint_total{status="failed"}[15m]) > 0
                for: 15m
                labels:
                  severity: warning
                annotations:
                  summary: "Relay token mint errors observed"
                  description: "web_agency_relay_token_mint_total{status=\"failed\"} has been increasing for more than 15 minutes (current rate {{ $value | printf \"%.4f\" }}/s)."
          - name: web-agency-admin
            rules:
              - alert: WebAgencySyncErrors
                expr: web_agency_sync_last_errors > 0
                for: 15m
                labels:
                  severity: warning
                annotations:
                  summary: "web-agency sync errors ({{ $labels.sync_type }})"
                  description: "Last sync cycle for sync_type={{ $labels.sync_type }} reported {{ $value }} errors and has not recovered for more than 15 minutes."
              - alert: WebAgencyCertRenewalFailures
                expr: web_agency_cert_renewal_last_results{status="failed"} > 0
                for: 30m
                labels:
                  severity: warning
                annotations:
                  summary: "Certificate renewal failures"
                  description: "Last cert renewal cycle reported {{ $value }} failures and has not recovered for more than 30 minutes."
              - alert: WebAgencyCertIssuanceFailures
                expr: web_agency_cert_issuance_last_results{status="failed"} > 0
                for: 30m
                labels:
                  severity: warning
                annotations:
                  summary: "Certificate issuance failures"
                  description: "Last cert issuance cycle reported {{ $value }} failures and has not recovered for more than 30 minutes."
              - alert: WebAgencyDeploymentFailureRate
                expr: rate(web_agency_deployments_total{status="failed"}[15m]) > 0
                for: 15m
                labels:
                  severity: warning
                annotations:
                  summary: "web-agency deployment failures observed"
                  description: "web_agency_deployments_total{status=\"failed\"} has been increasing for more than 15 minutes (current rate {{ $value | printf \"%.4f\" }}/s)."
      ''
    ];
  };

  services.oauth2-proxy = {
    enable = true;
    provider = "google";
    email.domains = [ "plan.ai" ];
    reverseProxy = true;
    setXauthrequest = true;
    cookie.domain = ".plan.ai";
    extraConfig.whitelist-domain = ".plan.ai";
    nginx.domain = "login.plan.ai";
    nginx.virtualHosts."prometheus.plan.ai" = { };
    nginx.virtualHosts."runner.plan.ai" = { };
  };

  services.xzar-server = {
    enable = true;
  };

  services.acme-distributor = {
    enable = true;
  };

  services.mac-mgmt-server = {
    enable = true;
  };

  services.mac-mgmt-runner = {
    enable = true;
  };

  services.mac-mgmt-relay = {
    enable = true;
    openFirewall = true;
    settings = {
      listen_addr = "127.0.0.1:7380";
      server_api_url = "https://api.plan.ai";
      proxy_hostname = "plan-ai-relay.com";
      proxy_url = "https://plan-ai-relay.com";
      data_dir = "/var/lib/mac-mgmt-relay";
      cors_origins = [ "https://mgmt.plan.ai" ];
    };
  };

  # libp2p QUIC enumerates interfaces via netlink
  systemd.services.mac-mgmt-relay.serviceConfig.RestrictAddressFamilies =
    lib.mkForce [ "AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK" ];

  # runner's preflight hits mac-mgmt at 127.0.0.1:7378 — without ordering, the
  # parallel start races and the first attempt exits 1 before systemd retries.
  # `after` only sequences process *fork*, not readiness — mac-mgmt isn't
  # Type=notify, so it takes a moment after fork to bind the port. Poll for it.
  systemd.services.mac-mgmt-runner = {
    after = [ "mac-mgmt.service" ];
    wants = [ "mac-mgmt.service" ];
    # /api/self returns 401 unauthenticated — that's fine, we only need to know
    # the port is bound, so drop -f and accept any HTTP response as readiness.
    serviceConfig.ExecStartPre =
      "${pkgs.bash}/bin/bash -c 'for i in $(seq 1 30); do ${pkgs.curl}/bin/curl -sS -o /dev/null --max-time 2 http://127.0.0.1:7378/api/self && exit 0; sleep 1; done; exit 1'";
  };

  services.kanbn = {
    enable = true;
    baseUrl = "https://kan.plan.ai";
    port = 3055;
    environmentFile = "/etc/kanbn.env";
    extraEnvironment = {
      NEXT_PUBLIC_DISABLE_SIGN_UP = "false";
      NEXT_PUBLIC_DISABLE_EMAIL = "true";
      LOG_LEVEL = "info";
      BETTER_AUTH_TRUSTED_ORIGINS = "https://kan.plan.ai";
      BETTER_AUTH_ALLOWED_DOMAINS = "plan.ai";
    };
  };

  services.hedgedoc = {
    enable = true;
    settings.domain = "docs.plan.ai";
  };

  services.zitadel.enable = true;

  services.plan-ai-chat = {
    enable = true;
    package = (pkgs.plan-ai-chat.override {
      envVars = {
        VITE_SUPABASE_URL = "https://tlssdiqdokctvxcezptr.supabase.co";
        VITE_SUPABASE_PUBLISHABLE_KEY = "sb_publishable_0jDsNegZ46CUSePRIj5-Bw_0_UYc41b";
      };
    }).overrideAttrs (old: {
      pnpmDeps = old.pnpmDeps.overrideAttrs (_: {
        outputHash = "sha256-sZHHfBDZLMP/AhkrXPaNvTbRXz3XHtPaVBXab4oGObo=";
      });
    });
    environmentFile = "/etc/plan-ai-chat.env";
  };

  services.supabase-self-service-consent = {
    enable = true;
    hostname = "127.0.0.1";
    port = 3636;
    NEXT_PUBLIC_SUPABASE_URL = "https://tlssdiqdokctvxcezptr.supabase.co";
    NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY = "sb_publishable_0jDsNegZ46CUSePRIj5-Bw_0_UYc41b";
  };

#  security.acme.distributor-server = "https://acme.plan.ai";
  security.acme.distributor-server = "http://localhost:3444";

  users.users.deploy = {
    isSystemUser = true;
    group = "deploy";
    # so the user can login
    shell = "/run/current-system/sw/bin/bash";

    openssh.authorizedKeys.keys = [
      ''command="${pkgs.rrsync}/bin/rrsync /srv/update/",no-agent-forwarding,no-port-forwarding,no-pty,no-user-rc,no-X11-forwarding ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIButBNqqpRpO+gMixN5J0HsLNEq26YIhXLC8wNHATs5W plan-ai-update''
    ];
  };
  users.groups.deploy = {};

  networking.hostName = "logos";
}
