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

      # Acting as the user (token exchange credentials: private). mgmt.plan.ai
      # accepts Zitadel bearers for project "mgmt.plan.ai API"; each user's
      # deployments come from the console.
      connector = {
        targets = [
          {
            name = "mac-mgmt";
            description = "plan.ai machine management (mgmt.plan.ai): your clusters' config, skills, bundles, MCP servers, SSH keys";
            kind = "mac-mgmt";
            mcp_url = "https://mgmt.plan.ai/mcp";
            audience_project_id = "397603440676569224";
          }
          {
            # Zitadel project "redream.plan.ai API".
            name = "redream";
            description = "redream.plan.ai: the plan.ai servers' iDRACs: power on/off/reset, status, console screenshots, display sessions";
            kind = "redream";
            mcp_url = "https://redream.plan.ai/mcp";
            audience_project_id = "398195680746668168";
          }
          {
            # Zitadel project "vpn.plan.ai API".
            name = "vpn";
            description = "vpn.plan.ai: your WireGuard devices: list, create, rename, regenerate keys, get configs";
            kind = "wg-vpng";
            mcp_url = "https://vpn.plan.ai/mcp";
            audience_project_id = "398195681300316296";
          }
        ];
        console = {
          url = "https://cloud.plan.ai";
          audience_project_id = "397603595463164040";
        };
      };

      # Token budgets are plans (accounts: "standard" default, "pro" 10x of
      # it; free, assigned per user on the admin dashboard).
      chat.max_chars = 2048;

      # mac-mgmt's public catalog for the sales agent (token: private).
      catalog.url = "https://mgmt.plan.ai/daemon/";
    };
  };
}
