orca:
{ config, lib, pkgs, ... }:
let
  program = config.programs.orca-ide;
  cfg = config.services.orca-ide;
  home = config.home.homeDirectory;
  environment = {
    HOME = home;
    XDG_CONFIG_HOME = config.xdg.configHome;
    XDG_CACHE_HOME = config.xdg.cacheHome;
    XDG_DATA_HOME = config.xdg.dataHome;
    XDG_STATE_HOME = config.xdg.stateHome;
    LIBGL_ALWAYS_SOFTWARE = "1";
    XDG_SESSION_TYPE = "x11";
    PATH = lib.makeBinPath
      ([ cfg.package ] ++ cfg.extraPackages ++ [
        config.home.profileDirectory
        "/run/wrappers"
        "/etc/profiles/per-user/${config.home.username}"
        "/run/current-system/sw"
        "${home}/.local"
        "/usr/local"
        "/usr"
      ]) + ":/bin";
  };
in
{
  imports = [
    (import ./options.nix {
      inherit config lib;
      packages = orca.packages.${pkgs.stdenv.hostPlatform.system};
    })
  ];

  config = lib.mkMerge [
    (lib.mkIf program.enable {
      home.packages = [ program.package ];
    })
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.home.username != "root";
          message = "services.orca-ide requires an unprivileged Home Manager account for its sandbox.";
        }
      ];
      home.packages = [ cfg.package ];
      systemd.user.services.orca-ide = {
        Unit = {
          Description = "Orca IDE runtime server";
          After = [ "network.target" ];
          StartLimitIntervalSec = 300;
          StartLimitBurst = 5;
        };
        Service = (import ./service-settings.nix { inherit lib cfg home; }) // {
          Environment = lib.mapAttrsToList (name: value: "${name}=${value}") environment;
        };
        Install.WantedBy = [ "default.target" ];
      };
    })
  ];
}
