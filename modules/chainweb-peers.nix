{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.chainweb-peers;

  start-chainweb-peers = pkgs.writeShellScript "start-chainweb-peers" ''
    ${pkgs.chainweb-peers}/bin/chainweb-peers
  '';
  start-tx-traces = pkgs.writeShellScript "start-tx-traces" ''
    ${pkgs.tx-traces}/bin/tx-traces
  '';

in
{
  options.services.chainweb-peers = {
    enable = mkEnableOption "chainweb-peers and tx-traces services";

    interval = mkOption {
      type = types.str;
      default = "5min";
      description = "How often to run chainweb-peers.";
    };

    databasePath = mkOption {
      type = types.path;
      default = "/var/lib/chainweb-peers/data.sqlite";
      description = "Path to the SQLite database for chainweb-peers.";
    };
  };

  config = mkIf cfg.enable {
    packages = [ pkgs.sqlite ];

    processes.tx-traces = {
      description = "TX Traces Service";
      after = [ "chainweb-peers.timer" ];
      requires = [ "chainweb-peers.timer" ];
      serviceConfig = {
        ExecStart = "${start-tx-traces} --db-path ${cfg.databasePath}";
        Restart = "on-failure";
      };
    };

    processes.chainweb-peers = {
      description = "Chainweb Peers Service - Run once and then controlled by timer";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${start-chainweb-peers} --output ${cfg.databasePath}";
      };
    };

    processes.timers.chainweb-peers = {
      description = "Timer for chainweb-peers service";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5m";
        OnUnitActiveSec = cfg.interval;
      };
    };
  };
}

