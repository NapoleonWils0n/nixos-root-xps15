{
  description = "NixOS configuration for Dell XPS 15 2019";

  inputs = {
    # NixOS official package source, pinned to the nixos-unstable
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs,... }@inputs: {
    # Define a NixOS system configuration
    # host name set to pollux
    nixosConfigurations.pollux = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux"; # This is where the system architecture is defined

      # Pass the 'inputs' attribute set to modules
      specialArgs = { inherit inputs; };

      modules = [
        # Import your existing configuration files
        ./configuration.nix
      ];

      # Define the 'pkgs' set, correctly passing the 'system' and now 'config'
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config = { # Pass nixpkgs.config options here
          allowUnfree = true;
        };
        overlays = [
          (import ./overlays/dwl-custom.nix) # Import the custom dwl overlay
          # Add any other system-level overlays here
        ];
      };
    };
  };
}
