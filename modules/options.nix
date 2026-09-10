{ config, lib, packages }:
{
  options = {
    programs.orca-ide = {
      enable = lib.mkEnableOption "Orca IDE";
      gui = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install the desktop launcher as well as the CLI. This does not start Orca.";
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = if config.programs.orca-ide.gui then packages.orca else packages.orca-cli;
        defaultText = lib.literalExpression "orca-nix.packages.\${system}.\${if config.programs.orca-ide.gui then \"orca\" else \"orca-cli\"}";
        description = "Orca package to install. The default follows the gui option.";
      };
    };

    services.orca-ide = {
      enable = lib.mkEnableOption "the headless Orca IDE server";
      package = lib.mkOption {
        type = lib.types.package;
        default = packages.orca-cli;
        defaultText = lib.literalExpression "orca-nix.packages.\${system}.orca-cli";
        description = "Headless-ready Orca package providing bin/orca and Xvfb.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 6768;
        description = "Server TCP port. This option does not open the firewall.";
      };
      pairingAddress = lib.mkOption {
        type = lib.types.nullOr lib.types.nonEmptyStr;
        default = null;
        example = "orca.example.ts.net";
        description = ''
          Address advertised to clients. Null lets Orca select the address.
          This does not change the listener bind address; Orca listens on all addresses.
          Use a private network and configure its firewall separately.
        '';
      };
      extraPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "Additional tools available on the server's PATH.";
      };
    };
  };
}
