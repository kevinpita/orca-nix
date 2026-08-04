{ lib
, stdenv
, fetchurl
, appimageTools
, symlinkJoin
, makeWrapper
,
}:

let
  pname = "orca";
  version = "1.4.168";

  sources = {
    x86_64-linux = {
      url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux.AppImage";
      hash = "sha512-JDoNfGu4nRa6oUicxWIG7ktOfLYtyIEz7FUfNiLnC6FDU1e6U2BaZrBHSkTTuV9Tq4mGd6SEGYiBF0XlA6X7Qg==";
    };
    aarch64-linux = {
      url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux-arm64.AppImage";
      hash = "sha512-8II0wF2sJWfN7C/Lsnl4Lre+4Zspos0xo5U96L61N6SEaPJgKjsYRPvITy+R1+whA/Uc4+XFgIA3HEnBah7+7A==";
    };
  };

  src = fetchurl (
    sources.${stdenv.hostPlatform.system}
      or (throw "orca is not supported on ${stdenv.hostPlatform.system}")
  );

  appimageContents = appimageTools.extractType2 {
    pname = "orca-ide";
    inherit version src;
  };

  extraPkgs = pkgs: with pkgs; [
    git
    openssh
  ];

  gui = appimageTools.wrapType2 {
    pname = "orca-ide";
    inherit version src extraPkgs;

    nativeBuildInputs = [ makeWrapper ];

    extraInstallCommands = ''
      install -m 444 -D ${appimageContents}/orca-ide.desktop $out/share/applications/orca-ide.desktop
      install -m 444 -D ${appimageContents}/orca-ide.png $out/share/icons/hicolor/512x512/apps/orca-ide.png
      substituteInPlace $out/share/applications/orca-ide.desktop \
        --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=orca-ide --no-sandbox %U'

      wrapProgram $out/bin/orca-ide \
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"
    '';
  };

  cli = appimageTools.wrapAppImage {
    pname = "orca";
    inherit version extraPkgs;
    src = appimageContents;
    runScript = "${appimageContents}/resources/bin/orca-ide";
  };
in
symlinkJoin {
  name = "${pname}-${version}";

  paths = [
    cli
    gui
  ];

  passthru = {
    inherit src appimageContents;
  };

  meta = {
    description = "ADE for working with a fleet of parallel agents";
    homepage = "https://github.com/stablyai/orca";
    changelog = "https://github.com/stablyai/orca/releases/tag/v${version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ kevinpita ];
    mainProgram = "orca";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
