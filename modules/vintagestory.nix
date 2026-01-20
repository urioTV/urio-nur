# Vintage Story NixOS Module
#
# This module provides an easy way to install Vintage Story with explicit version control.
# Both version and hash are REQUIRED - no auto-updates, full user control.
#
# Usage:
#   programs.vintagestory = {
#     enable = true;
#     version = "1.21.0";
#     hash = "sha256-90YQOur7UhXxDBkGLSMnXQK7iQ6+Z8Mqx9PEG6FEXBs=";
#   };
#
# To get hash for a new version:
#   nix-prefetch-url https://cdn.vintagestory.at/gamefiles/stable/vs_client_linux-x64_<VERSION>.tar.gz
#   nix hash convert --hash-algo sha256 --to sri <HASH>

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.vintagestory;

  # Inline package definition to avoid path issues in flakes
  vintagestoryPkg = pkgs.stdenv.mkDerivation {
    pname = "vintagestory";
    inherit (cfg) version;

    src = pkgs.fetchurl {
      url = "https://cdn.vintagestory.at/gamefiles/stable/vs_client_linux-x64_${cfg.version}.tar.gz";
      hash = cfg.hash;
    };

    nativeBuildInputs = with pkgs; [
      makeWrapper
      copyDesktopItems
    ];

    runtimeLibs = lib.makeLibraryPath (
      with pkgs;
      [
        gtk2
        sqlite
        openal
        cairo
        libGLU
        SDL2
        freealut
        libglvnd
        pipewire
        libpulseaudio
        xorg.libX11
        xorg.libXi
        xorg.libXcursor
      ]
    );

    desktopItems = [
      (pkgs.makeDesktopItem {
        name = "vintagestory";
        desktopName = "Vintage Story";
        exec = "vintagestory";
        icon = "vintagestory";
        comment = "Innovate and explore in a sandbox world";
        categories = [ "Game" ];
      })
    ];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/vintagestory $out/bin $out/share/pixmaps $out/share/fonts/truetype
      cp -r * $out/share/vintagestory
      cp $out/share/vintagestory/assets/gameicon.xpm $out/share/pixmaps/vintagestory.xpm
      cp $out/share/vintagestory/assets/game/fonts/*.ttf $out/share/fonts/truetype
      runHook postInstall
    '';

    preFixup = ''
      makeWrapper ${pkgs.dotnet-runtime_8}/bin/dotnet $out/bin/vintagestory \
        --prefix LD_LIBRARY_PATH : "$runtimeLibs" \
        --set-default mesa_glthread true \
        --add-flags $out/share/vintagestory/Vintagestory.dll

      makeWrapper ${pkgs.dotnet-runtime_8}/bin/dotnet $out/bin/vintagestory-server \
        --prefix LD_LIBRARY_PATH : "$runtimeLibs" \
        --set-default mesa_glthread true \
        --add-flags $out/share/vintagestory/VintagestoryServer.dll

      find "$out/share/vintagestory/assets/" -not -path "*/fonts/*" -regex ".*/.*[A-Z].*" | while read -r file; do
        local filename="$(basename -- "$file")"
        ln -sf "$filename" "''${file%/*}"/"''${filename,,}"
      done
    '';

    meta = {
      description = "In-development indie sandbox game about innovation and exploration";
      homepage = "https://www.vintagestory.at/";
      license = lib.licenses.unfree;
      sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
      platforms = lib.platforms.linux;
      mainProgram = "vintagestory";
    };
  };
in
{
  options.programs.vintagestory = {
    enable = lib.mkEnableOption "Vintage Story game";

    version = lib.mkOption {
      type = lib.types.str;
      description = ''
        The version of Vintage Story to install.
        Check https://www.vintagestory.at/download/ for available versions.
      '';
      example = "1.21.0";
    };

    hash = lib.mkOption {
      type = lib.types.str;
      description = ''
        SHA256 hash of the game archive (SRI format).

        To get the hash:
          nix-prefetch-url https://cdn.vintagestory.at/gamefiles/stable/vs_client_linux-x64_<VERSION>.tar.gz
          nix hash convert --hash-algo sha256 --to sri <HASH>
      '';
      example = "sha256-90YQOur7UhXxDBkGLSMnXQK7iQ6+Z8Mqx9PEG6FEXBs=";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = vintagestoryPkg;
      defaultText = lib.literalExpression "pkgs.vintagestory";
      description = "The Vintage Story package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
