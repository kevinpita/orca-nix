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
  version = "1.4.190";

  sources = {
    x86_64-linux = {
      url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux.AppImage";
      hash = "sha512-wn6RXyecm3gT3zPzArrPys3tjeNc8kOkes6UTYbiZ6wNzdLeY/hFZNAga35XYTKKeB75IS3bdZa1CF/hJQBM5Q==";
    };
    aarch64-linux = {
      url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux-arm64.AppImage";
      hash = "sha512-aUZeIV5UsqkOs3EjMhEP4Y7BiOq8ITuMqf7E29csKPVjG/g26cNfnt6b9zOC0O6ES95YF7y9JSBMevRjxpwFrw==";
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
