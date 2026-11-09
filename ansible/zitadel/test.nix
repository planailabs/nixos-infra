# The playbooks against a real Zitadel (Postgres 17, a first instance with a
# bootstrap machine user, as on webapp): everything is made, the credentials
# work, a second run changes nothing, and the rendered files are Nix.
# LiteLLM is a stand-in; the Harbor ssh step is off.
#
#   nix build .#checks.x86_64-linux.zitadel-ansible -L
{ pkgs }:

let
  playbooks = pkgs.lib.cleanSource ./.;
  vars = pkgs.writeText "test.yml" ''
    deployment: test
    zitadel_url: http://localhost:8080
    zitadel_pat_command: cat /var/lib/zitadel/bootstrap.pat
    partner_org_name: test-partner
    partner_login_name: Test Partner
    apps_project_name: test apps
    console_domain: cms.example.test
    agent_domain: agent.example.test
    harbor_domain: harbor.example.test
    admin_emails: [admin@example.test]
    internal_login_name: Test Internal
    internal_allowed_domains: [example.test]
    litellm_url: http://localhost:4000
    litellm_key_alias: test-chat
    harbor_ssh: ""
    harbor_database: harbor
  '';
  env = pkgs.lib.concatStringsSep " " [
    "GITHUB_CLIENT_ID=gh-id GITHUB_CLIENT_SECRET=gh-secret"
    "GOOGLE_CLIENT_ID=g-id GOOGLE_CLIENT_SECRET=g-secret"
    "INTERNAL_GOOGLE_CLIENT_ID=ig-id INTERNAL_GOOGLE_CLIENT_SECRET=ig-secret"
    "LITELLM_MASTER_KEY=master REGISTRY_ADMIN_TOKEN=registry CONTEXT7_API_KEY=c7"
  ];
  run = playbook: "cd ${playbooks} && HOME=/root ${env} ansible-playbook ${playbook} -e @${vars} -e private_dir=/tmp/private 2>&1";
  # what LiteLLM's /key/generate answers
  fakeLitellm = pkgs.writeText "litellm.py" ''
    import http.server, json
    class H(http.server.BaseHTTPRequestHandler):
        def do_POST(self):
            assert self.path == "/key/generate" and self.headers["Authorization"] == "Bearer master"
            body = json.dumps({"key": "sk-test"}).encode()
            self.send_response(200); self.send_header("Content-Type", "application/json"); self.end_headers()
            self.wfile.write(body)
    http.server.HTTPServer(("127.0.0.1", 4000), H).serve_forever()
  '';
in
pkgs.testers.runNixOSTest {
  name = "zitadel-ansible";
  nodes.machine = { pkgs, ... }: {
    virtualisation.memorySize = 3072;
    virtualisation.cores = 2;
    environment.systemPackages = [ pkgs.ansible pkgs.openssl pkgs.jq pkgs.curl ];

    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_17;   # Zitadel 2.71's setup fails on 18 (webapp/zitadel.nix)
      ensureDatabases = [ "zitadel" ];
      ensureUsers = [{ name = "zitadel"; ensureDBOwnership = true; ensureClauses = { createrole = true; createdb = true; }; }];
    };
    services.zitadel = {
      enable = true;
      tlsMode = "disabled";
      masterKeyFile = "${pkgs.writeText "masterkey" "MasterkeyNeedsToHave32Characters"}";
      settings = {
        Port = 8080;
        ExternalDomain = "localhost";
        ExternalPort = 8080;
        ExternalSecure = false;
        DefaultInstance.Features.TokenExchange = true;
        Database.postgres = {
          Host = "/run/postgresql";
          Port = 5432;
          Database = "zitadel";
          User = { Username = "zitadel"; SSL.Mode = "disable"; };
          Admin = { ExistingDatabase = "postgres"; Username = "zitadel"; SSL.Mode = "disable"; };
        };
      };
      steps.FirstInstance = {
        PatPath = "/var/lib/zitadel/bootstrap.pat";
        Org = {
          Name = "test";
          Machine = {
            Machine = { Username = "bootstrap"; Name = "bootstrap"; };
            Pat.ExpirationDate = "2099-01-01T00:00:00Z";
          };
        };
      };
    };
    systemd.services.zitadel = {
      requires = [ "postgresql.service" ];
      after = [ "postgresql.service" ];
      serviceConfig.StateDirectory = "zitadel";
    };
    systemd.services.fake-litellm = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig.ExecStart = "${pkgs.python3}/bin/python3 ${fakeLitellm}";
    };
  };

  testScript = ''
    import json
    machine.wait_for_unit("zitadel.service")
    machine.wait_until_succeeds("test -s /var/lib/zitadel/bootstrap.pat", timeout=600)
    machine.wait_until_succeeds("curl -sf http://localhost:8080/debug/ready", timeout=300)
    machine.wait_for_open_port(4000)
    machine.succeed("mkdir -m 700 /tmp/private")

    with subtest("setup makes everything, a second run nothing"):
        out = machine.succeed("${run "setup.yml"}")
        print(out)
        state = json.loads(machine.succeed("cat /tmp/private/test-zitadel.json"))
        for key in ["console_login", "agent_login", "harbor_login", "agent_exchange", "console_api", "harbor_api"]:
            assert state[key]["client_id"] and state[key]["client_secret"], key
        assert state["console_pat"] and state["agent_actor_key"]["keyId"]
        again = machine.succeed("${run "setup.yml"}")
        assert "changed=0" in again, again

    with subtest("the credentials work"):
        pat = state["console_pat"]
        api = lambda path: json.loads(machine.succeed(f"curl -sf -H 'Authorization: Bearer {pat}' http://localhost:8080{path}"))
        assert api("/admin/v1/policies/security")["policy"]["enableImpersonation"] is True
        # the console's API client introspects a token
        c = state["console_api"]
        r = json.loads(machine.succeed(
            f"curl -sf -u '{c['client_id']}:{c['client_secret']}' -d token={pat} http://localhost:8080/oauth/v2/introspect"))
        assert r["active"] is True, r
        org = state["partner_org_id"]
        policy = json.loads(machine.succeed(
            f"curl -sf -H 'Authorization: Bearer {pat}' -H 'x-zitadel-orgid: {org}' http://localhost:8080/management/v1/policies/login"))["policy"]
        assert not policy.get("isDefault") and policy["allowRegister"] and not policy.get("allowUsernamePassword"), policy
        assert sorted(i["idpName"] for i in policy["idps"]) == ["GitHub", "Google"], policy

    with subtest("a secret deleted from the state is made anew"):
        old = state["agent_login"]["client_secret"]
        machine.succeed("jq 'del(.agent_login.client_secret)' /tmp/private/test-zitadel.json > /tmp/s && mv /tmp/s /tmp/private/test-zitadel.json")
        machine.succeed("${run "setup.yml"}")
        new = json.loads(machine.succeed("cat /tmp/private/test-zitadel.json"))["agent_login"]["client_secret"]
        assert new and new != old

    with subtest("secrets renders Nix, and a second run changes nothing"):
        out = machine.succeed("${run "secrets.yml"}")
        print(out)
        for f in ["cloud", "chat", "harbor"]:
            machine.succeed(f"nix-instantiate --parse /tmp/private/test-{f}.nix")
        chat = machine.succeed("cat /tmp/private/test-chat.nix")
        assert '"sk-test"' in chat and "CONTEXT7_API_KEY" in chat and "FIRECRAWL" not in chat
        cloud = machine.succeed("cat /tmp/private/test-cloud.nix")
        assert '"Test Internal"' in cloud and '"Test Partner"' in cloud and "harbor.token" in cloud
        again = machine.succeed("${run "secrets.yml"}")
        assert "changed=0" in again, again
  '';
}
