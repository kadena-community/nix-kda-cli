{ pkgs, config, lib, ... }:

let
  cfg = config.services.txg;
  start-txg = pkgs.writeShellScript "start-txg" ''
    #!/bin/bash
    echo "Checking for cut"
    for (( i=1; i <=10; i++ ))
    do
        echo "Attempt $i"
        HEALTH=$(curl -sk -XGET https://localhost:1848/health-check)
        RESPONSE=$(curl -sk -XGET https://localhost:1848/chainweb/0.0/fast-development/cut)
        echo "got response"
        echo $RESPONSE | jq empty 2> /dev/null

        if [[ $? -eq 0 ]]; then
            echo "Cut found"
            echo $RESPONSE
            echo "health is $HEALTH"
            echo "Try again just to be sure"
        fi

        if [[ $i -eq 10 ]]; then
            echo "Just testing"
            exit 1
        fi
        sleep 1s
    done
    ${pkgs.txg}/bin/txg --config-file ${./txg/run-simple-expressions.yaml}
  '';
  cut-checker = pkgs.writeShellScript "cut-checker" ''
    #!/bin/bash
    echo "Checking for cut"
    for (( i=1; i <=10; i++ ))
    do
        RESPONSE=$(curl -sk -XGET https://localhost:1848/chainweb/0.0/cut)
        echo $RESPONSE | jq empty 2> /dev/null

        if [[ $? -eq 0 ]]; then
            echo "Cut found"
            exit 0
        fi
        # sleep 1s
    done
    echo "Cut not found"
    '';
in {
  options.services.txg = {
    enable = lib.mkEnableOption "txg";
  };
  config = lib.mkIf cfg.enable {
    packages = [ pkgs.txg ];
    processes.txg = {
      exec = "${pkgs.expect}/bin/unbuffer ${start-txg}";
      process-compose.depends_on = {
        chainweb-node.condition = "process_healthy";
        # script.condition = cut-checker;
      };
    };
    sites.landing-page.services.txg = {
      order = 10;
      markdown = ''
        ### Transaction Generator

      '';
    };
  };
}

