{ pkgs, config, ... }:

let

  start-chainweb-peers = pkgs.writeShellScript "start-chainweb-peers" ''
    ${pkgs.chainweb-peers}/bin/chainweb-peers --config-file ${chainweb-peers-config} --peer-registry-connection ${peerRegistryConnection}
  '';
  peerRegistryConnection = "sqlite-connection: ${databasePath}";
  databasePath = "/var/lib/chainweb-peers/data.sqlite";
  chainwebPeersConfigContent = config.chainweb-peers.chainwebPeersConfigContent or "";
  chainweb-peers-config = pkgs.writeText "chainweb-peers.conf" chainwebPeersConfigContent;
  txTracesConfigContent = config.chainweb-peers.txTracesConfigContent or "";
  tx-traces-config = pkgs.writeText "tx-traces.conf" txTracesConfigContent;
  elasticApiKey = config.chainweb-peers.elasticApiKey or "";
  elasticEndpoint = config.chainweb-peers.elasticEndpoint or "";
  start-tx-traces = pkgs.writeShellScript "start-tx-traces" ''
    ${pkgs.tx-traces}/bin/tx-traces --config-file ${tx-traces-config} --elastic-endpoint ${elasticEndpoint} --elastic-api-key ${elasticApiKey}
  '';

in
{
  config = {
    packages = [ pkgs.chainweb-peers pkgs.tx-traces pkgs.sqlite ];

    processes.chainweb-peers = {
      exec = "${pkgs.expect}/bin/unbuffer ${start-chainweb-peers}";
      process-compose.depends_on = {
        chainweb-node.condition = "process_healthy";
      };
    };
    processes.tx-traces = {
      exec = "${pkgs.expect}/bin/unbuffer ${start-tx-traces}";
    };

    # processes.chainweb-peers-dashboard = {
    #   exec = "${pkgs.echo}/bin/echo 'chainweb-peers-dashboard is not yet implemented'";
    # };

    services.ttyd.commands.chainweb-peers = "${start-chainweb-peers}/bin/start-chainweb-peers";

    services.elasticsearch.enable = true;

    sites.landing-page.services.chainweb-peers = {
      order = 10;
      markdown = ''
        ### Chainweb Peers

      '';
        # - [Chainweb Peers Dashboard](/chainweb-peers-dashboard)
    };
    sites.landing-page.commands.chainweb-peers.markdown = ''
      * `chainweb-peers-dashboard` - Chainweb Peers Dashboard
    '';
  };
}
# {
#   options.services.chainweb-peers = {
#     enable = mkEnableOption "chainweb-peers and tx-traces services";
#
#     interval = mkOption {
#       type = types.str;
#       default = "5min";
#       description = "How often to run chainweb-peers.";
#     };
#
#     elasticEndpoint = mkOption {
#       type = types.str;
#       default = "";
#       example = "https://elastic.example.com:9200";
#       description = "Elasticsearch endpoint.";
#     };
#
#     elasticApiKey = mkOption {
#       type = types.str;
#       default = "";
#       example = "elastic-api-key";
#       description = "Elasticsearch API key.";
#     };
#
#     peerRegistryConnection = mkOption {
#       type = types.str;
#       default = "sqlite-connection: ${cfg.databasePath}";
#       description = "Connection string for the peer registry.";
#     };
#
#     databasePath = mkOption {
#       type = types.path;
#       default = "/var/lib/chainweb-peers/data.sqlite";
#       description = "Path to the SQLite database for chainweb-peers.";
#     };
#
#     txTracesConfigContent = mkOption {
#       type = types.lines;
#       default = "";
#       example = ''
#         chainwebVersion: mainnet01
#         peersFile: null
#         peersRegistryConnection:
#           sqlite-connection: peers.sqlite
#       '';
#       description = "Content of the tx-traces config file.";
#     };
#
#     chainwebPeersConfigContent = mkOption {
#       type = types.lines;
#       default = "";
#       example = ''
#         PeerRegistryConnection:
#           sqlite-connection: peers.sqlite
#         bootstrapNodes:
#         - hostname: example1.chainweb.com
#           port: 443
#         - hostname: example2.chainweb.com
#           port: 443
#         dotFile: null
#         elasticApiKey: null
#         elasticEndpoint: null
#         locationsFile: null
#         logHandle: stdout
#         logLevel: info
#         network: mainnet
#         peersFile: peers.2023-08-25T171933.json
#         printStats: false
#         requestTimeout: 1000000
#       '';
#       description = "Content of the chainweb-peers config file.";
#     };
#   };
#
#   config = mkIf cfg.enable {
#     packages = [ pkgs.sqlite ];
#
#     # services.elasticsearch = {
#     #   enable = true;
#     #   package = pkgs.elasticsearch7;
#     #   clusterName = "chainweb-peers";
#     #   port = 9200;
#     # };
#
#     processes.tx-traces = {
#       description = "TX Traces Service";
#       after = [ "chainweb-peers.timer" ];
#       requires = [ "chainweb-peers.timer" ];
#       serviceConfig = {
#         ExecStart = "${start-tx-traces}";
#         Restart = "on-failure";
#       };
#     };
#
#     processes.chainweb-peers = {
#       description = "Chainweb Peers Service - Run once and then controlled by timer";
#       serviceConfig = {
#         Type = "oneshot";
#         ExecStart = "${start-chainweb-peers}";
#       };
#     };
#
#   };
# }

