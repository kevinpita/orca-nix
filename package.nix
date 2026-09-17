{ lib
, stdenv
, fetchurl
, appimageTools
, symlinkJoin
, makeWrapper
, withGui ? true
,
}:

let
  pname = "orca";
  version = "1.4.205";

  sources = {
    x86_64-linux = {
      url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux.AppImage";
      hash = "sha512-KnX9pst0OzdHSfHRSyDu1ARDOLHN6ipz7YjPItrqnPnfs4ey78w63p0TsxUfgaYUzymicSy+BbjgYIjoPkEtUQ==";
    };
    aarch64-linux = {
      url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux-arm64.AppImage";
      hash = "sha512-Ev9LoOXUVHFkz0w/2r7z+qWHbURhbOlOXfvtUO+OHRICB9TlO1wVaLui+Jc5ZSAmXB5Hb1jSuVphFSAMsSxgJw==";
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

  cli = appimageTools.wrapAppImage {
    pname = "orca";
    inherit version;
    extraPkgs = pkgs: extraPkgs pkgs ++ [ pkgs.xorg-server ];
    src = appimageContents;
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
