orca:
{ config, lib, pkgs, ... }:
let
  program = config.programs.orca-ide;
  cfg = config.services.orca-ide;
  defaultUser = "orca-ide";
  home = config.users.users.${cfg.user}.home or "/var/empty";
in
{
  imports = [
    (import ./options.nix {
      inherit config lib;
      packages = orca.packages.${pkgs.stdenv.hostPlatform.system};
    })
  ];

  options.services.orca-ide.user = lib.mkOption {
    type = lib.types.nonEmptyStr;
    default = defaultUser;
    example = "alice";
    description = ''
      Account that owns the server, repositories, and agent credentials.
      The default account is created with its home at /var/lib/orca-ide.
      Any other account must already be declared and have a writable home directory.
    '';
  };

  config = lib.mkMerge [
    (lib.mkIf program.enable {
      environment.systemPackages = [ program.package ];
    })
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.user != "root";
          message = "services.orca-ide.user must not be root; Orca requires an unprivileged account for its sandbox.";
        }
        {
          assertion = builtins.hasAttr cfg.user config.users.users && home != "/var/empty";
          message = "services.orca-ide.user must name a declared account with a home directory.";
        }
      ];

      environment.systemPackages = [ cfg.package ];

      users.users = lib.mkIf (cfg.user == defaultUser) {
        ${defaultUser} = {
          isSystemUser = true;
          group = defaultUser;
          home = "/var/lib/orca-ide";
          createHome = true;
          shell = pkgs.bashInteractive;
        };
      };
      users.groups = lib.mkIf (cfg.user == defaultUser) { ${defaultUser} = { }; };

      systemd.services.orca-ide = {
        description = "Orca IDE runtime server";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        path = [ cfg.package ] ++ cfg.extraPackages ++ [
          "/run/wrappers"
          "${home}/.nix-profile"
          "/etc/profiles/per-user/${cfg.user}"
          "/run/current-system/sw"
          "${home}/.local"
        ];
        environment = {
          HOME = home;
          LIBGL_ALWAYS_SOFTWARE = "1";
          XDG_SESSION_TYPE = "x11";
        };
        unitConfig = {
          StartLimitIntervalSec = 300;
          StartLimitBurst = 5;
        };
        serviceConfig = (import ./service-settings.nix { inherit lib cfg home; }) // {
          User = cfg.user;
        };
      };
    })
  ];
}
