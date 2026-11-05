# agent.plan.ai on the Rust chat server (plan-ai/chat), its agents on a
# subagent-net hub run by the same module (plan-ai-chat-subnet.service).
{ inputs, ... }: {
  imports = [ "${inputs.self.private}/logos-chat.nix" ];

  services.plan-ai-chat = {
    enable = true;
    settings = {
      database.url = "postgres://plan-ai-chat@localhost/plan-ai-chat?host=/run/postgresql";
      web.listen = "127.0.0.1:4321";   # nginx: agent.plan.ai -> localhost:4321

      # Zitadel project "plan.ai chat" in the plan.ai org; only that org's
      # accounts sign in. Client secret and cookie secret: private/logos-chat.nix.
      auth = {
        external_url = "https://agent.plan.ai";
        admin_emails = [ "maciej@plan.ai" ];
      };
      accounts.admin_emails = [ "maciej@plan.ai" ];

      # The agents' hub runs on logos too (services.plan-ai-chat.hub: `subnet
      # dev` with the chat package's chat.hcl). Its admin token, the callback
      # secret and the LiteLLM key: private/logos-chat.nix.
      subnet = {
        url = "http://127.0.0.1:7700";
        agent_type = "chat";
      };

      # Layer 2 of the tool approval: a cheap validator model through
      # LiteLLM (key "chat-prod": private/logos-chat.nix).
      approval = {
        validator_url = "https://codex.plan.ai/v1";
        validator_model = "deepseek-flash";
      };

      # Acting as the user (token exchange credentials: private); each user's
      # deployments come from the console.
      connector = {
        console = {
          url = "https://cloud.plan.ai";
          audience_project_id = "397603595463164040";
        };
      };

      # plan.ai applications: the sidebar's links and, with `mcp`, the services
      # the assistant acts on as the user (each takes Zitadel bearers for its
      # "<app> API" project). `emails` hides an app, in both places, from
      # everyone it doesn't match.
      apps = [
        {
          name = "plan-ai-cloud";
          description = "plan.ai Cloud (cloud.plan.ai): your organizations and deployments";
          kind = "plan-ai-cloud-web";
          url = "https://cloud.plan.ai";
          icon = "cloud";
          label = { en = "Cloud"; de = "Cloud"; };
        }
        {
          name = "web-agency";
          description = "plan.ai Web Agency (agency.plan.ai): your organizations' domains, subdomains, webspaces, certificates, contacts, billing, change detection";
          kind = "web-agency";
          url = "https://agency.plan.ai";
          icon = "agency";
          label = { en = "Web Agency"; de = "Webagentur"; };
          mcp = { url = "https://agency.plan.ai/mcp"; audience_project_id = "398201705830809736"; };
        }
        {
          name = "mac-mgmt";
          description = "plan.ai machine management (mgmt.plan.ai): your clusters' config, skills, bundles, MCP servers, SSH keys";
          kind = "mac-mgmt";
          url = "https://mgmt.plan.ai";
          icon = "machine";
          label = { en = "Machine management"; de = "Maschinenverwaltung"; };
          mcp = { url = "https://mgmt.plan.ai/mcp"; audience_project_id = "397603440676569224"; };
        }
        {
          name = "vpn";
          description = "vpn.plan.ai: your WireGuard devices: list, create, rename, regenerate keys, get configs";
          kind = "wg-vpng";
          url = "https://vpn.plan.ai";
          icon = "vpn";
          label = { en = "VPN"; de = "VPN"; };
          mcp = { url = "https://vpn.plan.ai/mcp"; audience_project_id = "398195681300316296"; };
        }
        {
          name = "redream";
          description = "redream.plan.ai: the plan.ai servers' iDRACs: power on/off/reset, status, console screenshots, display sessions";
          kind = "redream";
          url = "https://redream.plan.ai";
          icon = "server";
          label = { en = "Servers"; de = "Server"; };
          mcp = { url = "https://redream.plan.ai/mcp"; audience_project_id = "398195680746668168"; };
          emails = [ "*@plan.ai" ];
        }
      ];

      # Token budgets are plans (accounts: "standard" default, "pro" 10x of
      # it; free, assigned per user on the admin dashboard).
      chat.max_chars = 2048;

      # mac-mgmt's public catalog for the sales agent (token: private).
      catalog.url = "https://mgmt.plan.ai/daemon/";
    };
  };
}
