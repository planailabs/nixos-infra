{ inputs, ... }:

# agent.webapp.agency: the Rust chat (logos/chat.nix) for webapp.agency, its
# agents on a hub run by the same module. Signs in the webapp-agency org;
# acts as the user on cms.webapp.agency and harbor.webapp.agency. Secrets:
# private/webapp-chat.nix.
{
  imports = [ "${inputs.self.private}/webapp-chat.nix" ];

  services.plan-ai-chat = {
    enable = true;
    settings = {
      web.listen = "127.0.0.1:4321";

      auth = {
        external_url = "https://agent.webapp.agency";
        admin_emails = [ "maciej@plan.ai" ];
      };
      accounts.admin_emails = [ "maciej@plan.ai" ];

      subnet.agent_type = "chat";

      # A cheap validator model through codex's LiteLLM (key "webapp-chat").
      approval = {
        validator_url = "https://codex.plan.ai/v1";
        validator_model = "deepseek-flash";
      };

      # Acting as the user: deployments come from the console.
      connector.console = {
        url = "https://cms.webapp.agency";
        # project "cms.webapp.agency API" on id.webapp.agency
        audience_project_id = "398879340269404274";
      };

      apps = [
        {
          name = "plan-ai-cloud";
          description = "webapp.agency CMS (cms.webapp.agency): your organizations and sites";
          kind = "plan-ai-cloud-web";
          url = "https://cms.webapp.agency";
          icon = "cloud";
          label = { en = "CMS"; de = "CMS"; };
        }
        {
          name = "harbor";
          description = "webapp.agency Harbor (harbor.webapp.agency): your domains, subdomains, webspaces, certificates";
          kind = "harbor";
          url = "https://harbor.webapp.agency";
          icon = "agency";
          label = { en = "Harbor"; de = "Harbor"; };
          # project "harbor.webapp.agency API" on id.webapp.agency
          mcp = { url = "https://harbor.webapp.agency/mcp"; audience_project_id = "398879340923715698"; };
        }
      ];
    };
  };

  services.nginx.virtualHosts."agent.webapp.agency" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:4321/";
      proxyWebsockets = true;
      # The chat's event stream is SSE: don't buffer.
      extraConfig = ''
        proxy_buffering off;
        proxy_read_timeout 3600s;
      '';
    };
    # The hub's callbacks come from localhost only.
    locations."~ ^/(hooks|agent/mcp|connector/mcp)(/|$)".return = "404";
  };
}
