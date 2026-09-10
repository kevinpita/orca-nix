{ lib, cfg, home }:
let
  args = [
    "${cfg.package}/bin/orca"
    "serve"
    "--port"
    (toString cfg.port)
    "--json"
  ] ++ lib.optionals (cfg.pairingAddress != null) [ "--pairing-address" cfg.pairingAddress ];
  # systemd expands % specifiers and $ variables even in quoted arguments.
  escapeArg = arg: lib.replaceStrings [ "%" "$" ] [ "%%" "$$" ] (builtins.toJSON arg);
in
{
  ExecStart = lib.concatMapStringsSep " " escapeArg args;
  WorkingDirectory = home;
  UnsetEnvironment = [ "DISPLAY" "WAYLAND_DISPLAY" ];
  KillMode = "mixed";
  Restart = "on-failure";
  RestartPreventExitStatus = 3;
  RestartSec = 5;
}
