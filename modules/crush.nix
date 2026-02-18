# Crush Home Manager module with MCP integration.
# Re-exports the official charmbracelet/nur crush module and adds
# enableMcpIntegration option and providerApiKeyFiles.
{ charm-nur }:

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.crush;

  # Map generic MCP type names to Crush-compatible types
  mapType =
    t:
    {
      "remote" = "http";
      "local" = "stdio";
    }
    .${t} or t;

  # Transform a programs.mcp server entry into Crush's MCP format
  transformMcpServer =
    name: server:
    let
      detectedType = if server ? url then "http" else "stdio";
      rawType = server.type or detectedType;
    in
    lib.filterAttrs (_: v: v != null) (
      {
        type = mapType rawType;
      }
      // (lib.optionalAttrs (server ? command) { inherit (server) command; })
      // (lib.optionalAttrs (server ? args) { inherit (server) args; })
      // (lib.optionalAttrs (server ? url) { inherit (server) url; })
      // (lib.optionalAttrs (server ? env) { inherit (server) env; })
      // (lib.optionalAttrs (server ? headers) { inherit (server) headers; })
    );

  # Only transform if integration is enabled and there are servers configured
  transformedMcpServers =
    if cfg.enableMcpIntegration && config.programs.mcp.enable && config.programs.mcp.servers != { } then
      lib.filterAttrs (_: server: !(server.disabled or false)) (
        lib.mapAttrs transformMcpServer config.programs.mcp.servers
      )
    else
      { };

  crushConfigPath = "${config.xdg.configHome}/crush/crush.json";

  # Build jq commands to inject API keys into the JSON at runtime
  jqCommands = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: path: ''
      if [ -f "${path}" ]; then
        __apikey=$(cat "${path}" | tr -d '\n')
        __crushJson=$(${pkgs.jq}/bin/jq --arg key "$__apikey" '.providers.${name}.api_key = $key' "$__crushConfig")
        echo "$__crushJson" > "$__crushConfig"
      else
        echo "Warning: Crush API key file not found for provider '${name}': ${path}" >&2
      fi
    '') cfg.providerApiKeyFiles
  );
in
{
  # Re-export the official Charm NUR crush module
  imports = [ charm-nur.homeModules.crush ];

  options.programs.crush = {
    enableMcpIntegration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to integrate the MCP servers config from
        {option}`programs.mcp.servers` into
        {option}`programs.crush.settings.mcp`.

        Note: Settings defined in {option}`programs.mcp.servers` are merged
        with {option}`programs.crush.settings.mcp`, with Crush-specific
        settings taking precedence.
      '';
    };

    providerApiKeyFiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = lib.literalExpression ''
        {
          openrouter = config.sops.secrets.openrouter_api_key.path;
          anthropic = "/run/secrets/anthropic_key";
        }
      '';
      description = ''
        Attribute set mapping provider names to file paths containing
        API keys. The secrets are injected at activation time (runtime)
        using jq, making this compatible with sops-nix and agenix.
        The key is read from the file and placed into
        the provider's api_key field in crush.json.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Inject MCP servers from programs.mcp
      (lib.mkIf (transformedMcpServers != { }) {
        programs.crush.settings.mcp = transformedMcpServers;
      })

      # Activation script to inject API keys from files into crush.json at runtime
      (lib.mkIf (cfg.providerApiKeyFiles != { }) {
        home.activation.crushApiKeys = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          __crushConfig="${crushConfigPath}"
          if [ -f "$__crushConfig" ]; then
            ${jqCommands}
          fi
        '';
      })
    ]
  );
}
