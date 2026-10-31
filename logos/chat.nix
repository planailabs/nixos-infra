# chat.plan.ai on the Rust chat server (plan-ai/chat), its agents on a
# subagent-net hub. NOT imported yet: logos/default.nix still runs the Astro
# chat. To switch: bump the plan-ai-chat input to the Rust version, add
# ./chat.nix to the imports in default.nix, drop the old services.plan-ai-chat
# block there and /etc/plan-ai-chat.env in private/logos.nix.
{ inputs, ... }: {
  imports = [ "${inputs.self.private}/logos-chat.nix" ];

  services.plan-ai-chat = {
    enable = true;
    settings = {
      database.url = "postgres:///plan-ai-chat?host=/run/postgresql";
      web.listen = "127.0.0.1:4321";   # nginx: chat.plan.ai -> localhost:4321

      # Zitadel project "plan.ai chat" in the plan.ai org; only that org's
      # accounts sign in. Client secret and cookie secret: private/logos-chat.nix.
      auth = {
        external_url = "https://chat.plan.ai";
        admin_emails = [ "maciej@plan.ai" ];
      };
      accounts.admin_emails = [ "maciej@plan.ai" ];

      # Hub token (`subnet issue_token client chat`) and the callback secret:
      # private/logos-chat.nix. The hub runs ../subnet/chat.hcl of the chat repo.
      subnet = {
        url = "http://127.0.0.1:7700";
        types = { sales = "chat-sales"; machine_config = "chat-machine-config"; };
      };

      # Layer 2 of the tool approval (validator model) stays off until the
      # chat has a LiteLLM key of its own; static checks and the user decide.
      approval = { };

      chat = {
        hourly_input_tokens = 100000;
        hourly_output_tokens = 20000;
        max_chars = 2048;
      };

      # mac-mgmt's public catalog for the sales agent (token: private).
      catalog.url = "https://mgmt.plan.ai/daemon/";
    };
  };
}
