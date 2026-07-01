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
        jpcal       = final.callPackage ./pkgs/jpcal.nix { };
        apm         = llm-agents.packages.${final.system}.apm;
        claude-code = llm-agents.packages.${final.system}.claude-code;

        # Temporary shim: the nixos-unstable channel is currently pinned to a
        # nixpkgs commit that limits podman to `lib.platforms.linux` (nixpkgs
        # PR #536067), which makes aarch64-darwin refuse to evaluate. Upstream
        # already widened it back to `lib.platforms.unix` on master (#536759),
        # but that has not reached the channel yet. Re-widen meta.platforms so
        # podman keeps building on darwin. Remove once the channel advances
        # past commit c96fe92bf.
        podman = prev.podman.overrideAttrs (old: {
          meta = old.meta // { platforms = prev.lib.platforms.unix; };
        });
      };

      mkPkgs = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ customPackagesOverlay ];
      };

      pkgsFor = {
        "aarch64-darwin" = mkPkgs "aarch64-darwin";
        "aarch64-linux"  = mkPkgs "aarch64-linux";
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
          # nix-darwin の system activation は root で走るが homebrew 等の
          # オプションは特定ユーザー向けに作用するので primaryUser を明示する。
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
        # Google Pixel "Linux Terminal" (Android AVF / Debian aarch64 VM).
        android = mkHome {
          system = "aarch64-linux";
          extraModule = ./home/linux.nix;
        };
      };

      # activation script から `nix run .#home-manager` を呼べるよう pin した
      # home-manager を再公開する。`home-manager/master` 直 ref だと毎回 GitHub
      # API を叩いて anonymous rate limit を踏む (nix-daemon は session 中に
      # /etc/nix/nix.conf を reload しないので access-tokens を設定しても効かない)。
      packages = builtins.mapAttrs
        (system: _: { home-manager = home-manager.packages.${system}.default; })
        pkgsFor;
    };
}
