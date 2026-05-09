{
  description = "chezmoi-dotfiles: Nix side (Home Manager + nix-darwin)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nix-darwin, ... }:
    let
      username = builtins.getEnv "USER";

      jpcalOverlay = final: prev: {
        jpcal = final.callPackage ./pkgs/jpcal.nix { };
      };

      mkPkgs = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ jpcalOverlay ];
      };

      pkgsFor = {
        "aarch64-darwin" = mkPkgs "aarch64-darwin";
        "x86_64-linux"   = mkPkgs "x86_64-linux";
      };

      mkHome = { system, extraModule }: home-manager.lib.homeManagerConfiguration {
        pkgs = pkgsFor.${system};
        modules = [ ./home/common.nix extraModule ];
      };

      mkDarwin = { system }: nix-darwin.lib.darwinSystem {
        inherit system;
        modules = [
          ./darwin/configuration.nix
          { nixpkgs.pkgs = pkgsFor.${system}; }
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${username} = {
              imports = [ ./home/common.nix ./home/darwin.nix ];
            };
          }
        ];
      };
    in {
      darwinConfigurations.default = mkDarwin { system = "aarch64-darwin"; };

      homeConfigurations = {
        linux = mkHome {
          system = "x86_64-linux";
          extraModule = ./home/linux.nix;
        };
        wsl = mkHome {
          system = "x86_64-linux";
          extraModule = { imports = [ ./home/linux.nix ./home/wsl.nix ]; };
        };
      };
    };
}
