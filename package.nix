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
  version = "1.4.176";

  sources = {
    x86_64-linux = {
      url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux.AppImage";
      hash = "sha512-RlhVY+tD0u8T6UpOT+/tfFd/AHIaD5wlM4A4DB4on2Wfo5BpIM/qppFoZzUYab8dXAHy+H117EFNXmaovJmofA==";
    };
    aarch64-linux = {
      url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux-arm64.AppImage";
      hash = "sha512-Ni/EazHG24V7RxRZs31PUQiZp5GIEdMW8cc1bfM6HYNgyQLkT6c7+5kvjODCuFTaKiUPV2d0LBwUBGfPmJoHSw==";
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
