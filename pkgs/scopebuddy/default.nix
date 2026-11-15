{
  stdenv,
  lib,
  fetchFromGitHub,
  makeWrapper,
  bash,
  gamescope,
  perl,
  jq,
  libglvnd,
  pkgsi686Linux,
  glibc,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "scopebuddy";
  version = "1.5.0";

  src = fetchFromGitHub {
    owner = "OpenGamingCollective";
    repo = "ScopeBuddy";
    tag = finalAttrs.version;
    hash = "sha256-Z4KE6Qs5dcNdoEra1sx69I8EsxztAeVNGgO0ltYz7r0=";
  };

  nativeBuildInputs = [ makeWrapper ];

  # glibc.static is needed only to link the static launcher; it is not part of
  # the runtime closure because the launcher references nothing dynamic.
  buildInputs = [
    bash
    (gamescope.overrideAttrs (_: {
      NIX_CFLAGS_COMPILE = [ "-fno-fast-math" ];
    }))
    perl
    jq
    glibc.static
  ];

  # Launcher and script layout: bin/scopebuddy is a static ELF that sets the
  # libGL preload for Steam's overlay and then runs libexec/scopebuddy/scopebuddy
  # with bash. See launcher.c for why this must not be a shell script.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/libexec/scopebuddy
    install -Dm755 bin/scopebuddy $out/libexec/scopebuddy/scopebuddy
    wrapProgram $out/libexec/scopebuddy/scopebuddy \
      --prefix PATH : ${
        lib.makeBinPath [
          bash
          (gamescope.overrideAttrs (_: {
            NIX_CFLAGS_COMPILE = [ "-fno-fast-math" ];
          }))
          perl
          jq
        ]
      } \
      --set SCB_AUTO_RES "1" \
      --set SCB_AUTO_HDR "1" \
      --set SCB_AUTO_VRR "1"

    $CC -static -O2 -Wall -Wextra -Werror \
      -DSCB_BASH='"${bash}/bin/bash"' \
      -DSCB_LIBGL64='"${libglvnd}/lib/libGL.so.1"' \
      -DSCB_LIBGL32='"${pkgsi686Linux.libglvnd}/lib/libGL.so.1"' \
      -DSCB_SCRIPT_REL='"../libexec/scopebuddy/scopebuddy"' \
      -o $out/bin/scopebuddy ${./launcher.c}
    strip $out/bin/scopebuddy

    ln -s $out/bin/scopebuddy $out/bin/scb

    runHook postInstall
  '';

  meta = with lib; {
    description = "A manager script to make gamescope easier to use on desktop";
    homepage = "https://github.com/OpenGamingCollective/ScopeBuddy";
    license = licenses.asl20;
    platforms = platforms.linux;
    mainProgram = "scopebuddy";
  };
})
