{
  # Default overlay that adds all packages from this NUR repository
  default = final: prev: {
    vintagestory = final.callPackage ../pkgs/vintagestory { };
    cybergrub2077 = final.callPackage ../pkgs/cybergrub2077 { };
    wowup-cf = final.callPackage ../pkgs/wowup-cf { };
    scopebuddy = final.callPackage ../pkgs/scopebuddy { };
  };
}
