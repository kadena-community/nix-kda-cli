{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    devenv.url = "github:cachix/devenv";
    chainweb-node.url = "github:kadena-io/chainweb-node/emmanuel/fast-devnet-changes";
    chainweb-node-l2.url = "github:kadena-io/chainweb-node/edmund/l2-spv-poc";
    chainweb-data = {
      url = "github:kadena-io/chainweb-data";
      inputs.nixpkgs.follows = "chainweb-node/nixpkgs";
      inputs.haskellNix.follows = "chainweb-node/haskellNix";
    };
    chainweb-mining-client = {
      url = "github:kadena-io/chainweb-mining-client/enis/update-to-flakes-and-haskellNix";
      inputs.haskellNix.follows = "chainweb-node/haskellNix";
      inputs.nixpkgs.follows = "chainweb-node/nixpkgs";
    };
    txg = {
      url = "github:kadena-io/txg/6022a7d8d64f57be42d3c2f3d8204c8dafd21ea5"; # the current txg commit on the branch emmanuel/nix-flake
      inputs.haskellNix.follows = "chainweb-node/haskellNix";
      inputs.nixpkgs.follows = "chainweb-node/nixpkgs";
    };
    chainweb-peers = {
      # url = "git+ssh://git@github.com/kadena-io/chainweb-peers?ref=emmanuel/include-different-networks";
      url = "git+ssh://git@github.com/kadena-io/chainweb-peers?ref=emmanuel/include-different-networks&rev=7289c85a1f320b66c7a781c3cf88f591a7d5c00c";
      inputs.haskellNix.follows = "chainweb-node/haskellNix";
      inputs.nixpkgs.follows = "chainweb-node/nixpkgs";
    };
    pact = {
      url = "github:kadena-io/pact";
      inputs.haskellNix.follows = "chainweb-node/haskellNix";
      inputs.nixpkgs.follows = "chainweb-node/nixpkgs";
    };
    block-explorer.url = "github:kadena-io/block-explorer/enis/devnet-support";
    nix-exe-bundle = { url = "github:3noch/nix-bundle-exe"; flake = false; };
  };

  outputs = { self
            , nixpkgs
            , devenv
            , ... } @ inputs:
    inputs.flake-utils.lib.eachDefaultSystem (system: let
      bundle = pkgs.callPackage inputs.nix-exe-bundle {};
      get-flake-info = import lib/get-flake-info.nix inputs;
      bundleWithInfo = inputs: let
        get-flake-info = import lib/get-flake-info.nix inputs;
        in flakeName: let
          flakeInfo = get-flake-info flakeName;
          default = inputs.${flakeName}.packages.${system}.default;
        in bundle default // {
          inherit flakeInfo;
          version = default.version or default.meta.version or null;
        };
      bundleWithInfo' = bundleWithInfo inputs;
      overlay = (self: super: {
        chainweb-data = bundleWithInfo' "chainweb-data";
        chainweb-mining-client = bundleWithInfo' "chainweb-mining-client";
        chainweb-node = bundleWithInfo' "chainweb-node";
        chainweb-peers = bundle inputs.chainweb-peers.packages.${system}.default;
        txg = bundle inputs.txg.packages.${system}.default;
        tx-traces = bundle inputs.chainweb-peers.packages.${system}.tx-traces;
        pact = bundleWithInfo' "pact";
        block-explorer = inputs.block-explorer.packages.x86_64-linux.static // {
          flakeInfo = get-flake-info "block-explorer";
        };
      });
      chainweb-node-l2 = bundleWithInfo' "chainweb-node-l2";
      pkgs = import nixpkgs { inherit system; overlays = [ overlay ]; };
      modules = [
        # https://devenv.sh/reference/options/
        modules/chainweb-data.nix
        modules/chainweb-node.nix
        modules/chainweb-mining-client.nix
        modules/chainweb-peers.nix
        modules/cut-checker.nix
        modules/mempoolPending.nix
        modules/txg.nix
        modules/http-server.nix
        modules/ttyd.nix
        modules/landing-page/module.nix
        modules/pact-cli.nix
        modules/process-compose.nix
        modules/devnet-mode.nix
        modules/explorer.nix
      ];
      packageExtras = {
      };
      containerExtras = with pkgs.lib; {config, ...}:  {
        devenv.root = "/devnet";
        services.chainweb-data.extra-migrations-folder = "/cwd-extra-migrations";
        sites.landing-page.container-api.enable = true;
        imports = [
          (mkIf config.services.postgres.enable {
            processes.socat.exec = ''
              ${pkgs.socat}/bin/socat TCP-LISTEN:5432,reuseaddr,fork \
                UNIX-CONNECT:${config.env.PGDATA}/.s.PGSQL.5432
            '';
            sites.landing-page.container-api.ports = mkAfter
              "- `5432`: Postgresql";
          })
        ];
        sites.landing-page.container-api.folders = mkBefore "- `/data`: Persistent data folder";
      };
      mkFlake = containerTag: extraModule:
        import ./mkDevnetFlake.nix {
          inherit pkgs nixpkgs devenv containerExtras packageExtras containerTag;
          modules = modules ++ [extraModule];
        };
      configurations = let
        minimal = {
          services.chainweb-node.enable = true;
          services.chainweb-mining-client.enable = true;
          services.http-server.enable = true;
        };
        chainweb-peers = {
          imports = [minimal];
          services.elasticsearch.enable = true;
          services.chainweb-peers.enable = true;
          services.cut-checker.enable = true;
          services.txg.enable = true;
          # services.mempoolPending.enable = true;
        };
        local = {
          imports = [minimal];
          services.chainweb-data.enable = true;
          sites.explorer.enable = true;
        };
        container-common = {
          imports = [local];
          services.ttyd.enable = true;
          services.pact-cli.enable = true;
        };
        use-cwn-l2 = {
          services.chainweb-node.package = chainweb-node-l2;
        };
        # Useful for iterating on nginx configurations
        http-only = {
          services.http-server.enable = true;
          # Keep process-compose alive even if nginx dies
          processes.sleep.exec = "sleep 100";
          sites.explorer.enable = true;
        };
      in {
        default = local;
        container-default = container-common;
        l2 = { imports = [container-common use-cwn-l2]; };
        minimal = minimal;
        inherit chainweb-peers;
        inherit http-only;
      };
      combined-flake = import lib/combine-flakes.nix pkgs.lib (
        builtins.mapAttrs (cfgName: config: mkFlake cfgName config) configurations
      );
      in pkgs.lib.recursiveUpdate combined-flake {
        apps.develop-page = {
          type = "app";
          program = (import ./lib/develop-page.nix {inherit pkgs;}).outPath;
        };
        inherit configurations;
        overlays.default = overlay;
        lib = { inherit mkFlake bundleWithInfo; };
      });
}
