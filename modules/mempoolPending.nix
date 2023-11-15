{ pkgs, config, lib, ... }:

let
  cfg = config.services.mempoolPending;
  mempoolPending = pkgs.writeShellScript "mempoolPending" ''
    #/bin/bash
    echo "Starting mempoolPending"
    for (( i = 0; i < 1000 ; i++))
    do
        # RESPONSE=$(curl -skv -XPOST https://localhost:1848/chainweb/0.0/fast-development/chain/0/mempool/getPending)
        RESPONSE=$(curl -sk -XPOST https://localhost:1789/chainweb/0.0/fast-development/chain/0/mempool/getPending)
        echo "Attempt $i"
        echo $RESPONSE
        sleep 3s
    done
    '';
in {
  options.services.mempoolPending = {
    enable = lib.mkEnableOption "mempoolPending";
   };
   config = lib.mkIf cfg.enable {
     processes.mempoolPending = {
       exec = "${pkgs.expect}/bin/unbuffer ${mempoolPending}";
       process-compose.depends_on = {
         chainweb-node.condition = "process_healthy";
       };
     };
   };
}

