# overlays/dwl-custom.nix
self: super: {
  dwl = super.dwl.overrideAttrs (oldAttrs: {
    # Add your movestack.patch
    patches = (oldAttrs.patches or []) ++ [
      (super.lib.cleanSourceWith {
        src = ../dwl/movestack.patch; # Path relative to this overlay file
        name = "movestack-patch";
      })
    ];

    # Copy your custom config.h into the build directory
    postPatch = (oldAttrs.postPatch or "") + ''
      cp ${super.lib.cleanSourceWith {
        src = ../dwl/config.h; # Path relative to this overlay file
        name = "dwl-config-h";
      }} config.h
    '';
  });

  # If dwlb also needs customization, it would go here.
  # Otherwise, dwlb is just included as a regular package.
}
