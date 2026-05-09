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

    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nix-darwin, llm-agents, nix-vscode-extensions, ... }:
    let
      username = builtins.getEnv "USER";

      customPackagesOverlay = final: prev: {
        jpcal = final.callPackage ./pkgs/jpcal.nix { };
        apm   = llm-agents.packages.${final.system}.apm;
      };

      mkPkgs = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ customPackagesOverlay ];
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
          # nix-darwin の system activation は root で走るが、homebrew 等の
          # オプションは特定ユーザー向けに作用する。primaryUser を明示する。
          { system.primaryUser = username; }
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit nix-vscode-extensions; };
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
