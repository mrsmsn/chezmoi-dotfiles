{
  description = "chezmoi-dotfiles: Nix side (Home Manager + nix-darwin + NixOS)";

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

    nixos-hardware.url = "github:NixOS/nixos-hardware";

    xremap = {
      url = "github:xremap/nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # niri (scrollable-tiling Wayland compositor)。あえて inputs.nixpkgs.follows
    # は付けない: follows すると niri.cachix.org のバイナリキャッシュとハッシュが
    # ずれ、niri 本体 (Rust) を毎回ローカルフルビルドすることになるため。
    niri.url = "github:sodiboo/niri-flake";

    # Noctalia (Quickshell ベースのデスクトップシェル: バー/ランチャー/通知/
    # ロック/壁紙/OSD)。v5 は nixpkgs 未収録 (nixpkgs は v4 系) なので flake から
    # 入れる。重い依存の quickshell は nixpkgs 側にあるので follows で nixos.org
    # キャッシュを使わせる (noctalia 本体は QML で軽量)。
    noctalia = {
      url = "github:noctalia-dev/noctalia";
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

  outputs = { self, nixpkgs, home-manager, nix-darwin, nixos-hardware, xremap, llm-agents, nix-vscode-extensions, niri, noctalia, ... }:
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
        # niri.overlays.niri は pkgs.niri-stable / niri-unstable を生やす。
        # このリポジトリは nixosSystem に nixpkgs.pkgs を注入する構成なので、
        # niri モジュール (nixpkgs.overlays を自前設定しない設計) に pkgs.niri-stable
        # を届けるには overlay をこの注入 pkgs 側に組み込む必要がある。overlay 方式は
        # niri の依存 (特に mesa) を system の nixpkgs に整合させ、GPU 描画を保証する。
        overlays = [ customPackagesOverlay niri.overlays.niri ];
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
      mkNixos = { system }: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./nixos/configuration.nix
          # hardware-configuration.nix はマシン固有情報のためリポジトリに置かない。
          # 実機では /etc/nixos の自動生成物を --impure で参照、CI では stub。
          (if builtins.pathExists /etc/nixos/hardware-configuration.nix
           then /etc/nixos/hardware-configuration.nix
           else ./nixos/ci-hardware-stub.nix)
          { nixpkgs.pkgs = pkgsFor.${system}; }
          nixos-hardware.nixosModules.common-cpu-intel
          nixos-hardware.nixosModules.common-pc-ssd
          xremap.nixosModules.default
          niri.nixosModules.niri
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # noctalia の home-manager モジュール (./home/nixos.nix で import) が
            # flake input を参照できるよう extraSpecialArgs で渡す。
            home-manager.extraSpecialArgs = { inherit noctalia; };
            # ./home/nixos.nix は nixos variant 専用 (WSL/android の
            # homeConfigurations には import されないので Noctalia は波及しない)。
            home-manager.users.${username}.imports = [ ./home/common.nix ./home/linux.nix ./home/nixos.nix ];
          }
        ];
      };
    in {
      darwinConfigurations.default = mkDarwin { system = "aarch64-darwin"; };

      nixosConfigurations.default = mkNixos { system = "x86_64-linux"; };

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
