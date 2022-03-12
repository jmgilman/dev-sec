{
  description = "Build image";
  inputs.nixpkgs.url = "github:nixos/nixpkgs";
  outputs = { self, nixpkgs }: rec {
    nixosConfigurations.rpi = nixpkgs.lib.nixosSystem rec {
      system = "aarch64-linux";
      modules = [
        "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
        ({ pkgs, config, ... }: {
          # TODO: update when zfs is compatible with latest kernel
          boot.kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;

          services.pcscd.enable = true; # smart card daemon
          services.udev.packages = [ pkgs.yubikey-personalization ];

          # Required packages for managing yubikeys
          environment.systemPackages = [
            pkgs.cryptsetup
            pkgs.gnupg
            pkgs.jq
            pkgs.pinentry-curses
            pkgs.pinentry-qt
            pkgs.paperkey
            pkgs.rng-tools
            pkgs.wget
            (pkgs.writeScriptBin "key_build" (builtins.readFile ./key_build.sh))
            (pkgs.writeScriptBin "key_open" (builtins.readFile ./key_open.sh))
            (pkgs.writeScriptBin "key_workspace" (builtins.readFile ./key_workspace.sh))
          ];

          environment.etc."key/gpg.conf" = {
            mode = "0644";
            text = (builtins.readFile ./gpg.conf);
          };

          environment.etc."key/gpg-agent.conf" = {
            mode = "0644";
            text = (builtins.readFile ./gpg-agent.conf);
          };

          # Use default nixos user with no password and enable autologin
          users.users.nixos = {
            isNormalUser = true;
            extraGroups = [ "wheel" "networkmanager" "video" ];
            initialHashedPassword = "";
          };
          services.getty.autologinUser = "nixos";

          # No password on root
          users.users.root.initialHashedPassword = "";

          # No password with sudo
          security.sudo = {
            enable = true;
            wheelNeedsPassword = false;
          };

          # Don't start SSH agent, gnupg needed for generating keys
          programs = {
            ssh.startAgent = false;
            gnupg.agent = {
              enable = true;
              enableSSHSupport = true;
            };
          };
        })
      ];
    };
    images.rpi = nixosConfigurations.rpi.config.system.build.sdImage;
  };
}