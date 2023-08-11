{pkgs, lib, config, ...}:
with pkgs.lib;
let
  cfg = config.sites.landing-page;
  mkSection = subsections: concatStringsSep "\n" (
    map (section: section.markdown) (
      builtins.sort (a: b: a.order < b.order)
        (builtins.attrValues subsections)
    )
  );
  landing-page-root = pkgs.runCommand "landing-page" {} ''
    mkdir -p $out
    ${pkgs.mustache-go}/bin/mustache \
      ${builtins.toFile "index-md-input.json" (builtins.toJSON {
        services = mkSection cfg.services;
        commands = mkSection cfg.commands;
      })} \
      ${./index.md.mustache} \
      > index.md

    ${pkgs.pandoc}/bin/pandoc --template=${./index.html} -s index.md -o $out/index.html
    ln -s ${./static} $out/static
  '';
  sectionsType = types.attrsOf (types.submodule {
    options = {
      order = mkOption {
        type = types.int;
        description = "Order of the subsection";
        default = 0;
      };
      markdown = mkOption {
        type = types.lines;
        description = "Content of the service subsection";
        default = "";
        example = ''
          ## My Service
          * [Service Link](/my-service/)
        '';
      };
    };
  });
in
{
  # The following should be a NixOS module option containing a path to a directory containing index.md, index.html, and static/
  options.sites.landing-page = {
    root = lib.mkOption {
      type = lib.types.package;
      default = landing-page-root;
      description = "The path to the compiled landing page folder.";
    };
    services = mkOption {
      default = {};
      type = sectionsType;
      description = "Subsections of the Services section.";
    };
    commands = mkOption {
      default = {};
      type = sectionsType;
      description = ''Subsections of the "Available Commands" section.'';
    };
  };

  config = {
    services.http-server.servers.devnet.extraConfig = ''
      location / {
        alias ${cfg.root}/;
      }
    '';
  };
}