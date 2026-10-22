# Convenience package sets, not derivations/CI roots. Module packages use the
# consumer nixpkgs while the kernel keeps its private, cache-compatible pin.
{ pkgs, kernels }:
if (pkgs.stdenv.hostPlatform.system or null) != "x86_64-linux" then
  { }
else
  {
    linuxPackages-cachyos-latest-x86_64-v3 = pkgs.linuxPackagesFor kernels.linux-cachyos-latest-x86_64-v3;
    linuxPackages-cachyos-bore-x86_64-v3 = pkgs.linuxPackagesFor kernels.linux-cachyos-bore-x86_64-v3;
  }
