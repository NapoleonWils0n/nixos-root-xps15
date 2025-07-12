# your-flake-root/flake.nix
{
  description = "NixOS configuration for Dell XPS 15 2019";

  inputs = {
    # NixOS official package source, pinned to the nixos-unstable
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs,... }@inputs: {
    # Define a NixOS system configuration
    # host name set to pollux, change the hostname for your system
    nixosConfigurations.pollux = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux"; # Specify the system architecture
      specialArgs = { inherit inputs; }; # Pass the 'inputs' attribute set to modules
      modules = [
        # Import your existing configuration files
        ./configuration.nix
      ];
    };
  };
}
