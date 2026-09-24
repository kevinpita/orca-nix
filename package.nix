{ lib
, stdenv
, fetchurl
, appimageTools
, buildFHSEnv
, symlinkJoin
, makeWrapper
, withGui ? true
,
}:

let
  pname = "orca";
  version = "1.4.210";

  sources = {
    x86_64-linux = {
      url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux.AppImage";
      hash = "sha512-+xUF8pNLo4X3SoMUpAa8+RMefo/R/Gx7GLwcMDfI1PsHK0z62f37aKzltWKqFkVCi0ihGVioZTw6FXatkPdH7w==";
    };
    aarch64-linux = {
      url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux-arm64.AppImage";
      hash = "sha512-o0FC/kTPfhZsas2yRoqy56crcB2JuGiE6BK6hmJqDfMigUqB0R+d8yn7cvGqs4o2C18Jd2B1kG6C82Blip9+Pg==";
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
        --replace-fail 'Exec=AppRun ' 'Exec=orca-ide '

      wrapProgram $out/bin/orca-ide \
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"
    '';
  };

  # The generic AppImage FHS environment pulls in a desktop-sized set of unrelated
  # libraries. Keep the Electron runtime, but include only its Linux dependencies.
  cli = buildFHSEnv {
    pname = "orca";
    inherit version;
    targetPkgs = pkgs: [ pkgs.gitMinimal pkgs.openssh pkgs.xorg-server ];
    multiPkgs = pkgs: with pkgs; [
      glib
      nspr
      nss
      atk
      at-spi2-atk
      at-spi2-core
      cups
      dbus
      cairo
      gtk3
      pango
      libx11
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxrandr
      libxtst
      libgbm
      libdrm
      expat
      libxcb
      libxkbcommon
      udev
      alsa-lib
      fontconfig
      libGL
    ];
    runScript = "${appimageContents}/resources/bin/orca-ide";
  };
in
symlinkJoin {
  name = "${pname}${lib.optionalString (!withGui) "-cli"}-${version}";

  paths = [ cli ] ++ lib.optional withGui gui;

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
