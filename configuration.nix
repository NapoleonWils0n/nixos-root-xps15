# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

let
  # 1. Define your customized dwl package
  myCustomDwlPackage = (pkgs.dwl.override {
    configH = ./dwl/config.h;
  }).overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or []) ++ [
      ./dwl/movestack.patch # Using the direct path for the patch
    ];
    # Add any necessary buildInputs if your config.h or patches require them
    # For a bar, you might need fcft for font rendering.
    buildInputs = oldAttrs.buildInputs or [] ++ [ pkgs.libdrm pkgs.fcft ];
  });

  # 2. Create a wrapper script that launches dwl with dwlb as the status bar
  dwlWithDwlbWrapper = pkgs.writeScriptBin "dwl-with-dwlb" ''
      #!/bin/sh
      # launch your customized dwl with its arguments
      exec ${lib.getExe myCustomDwlPackage} -s "${pkgs.dwlb}/bin/dwlb -font \"monospace:size=16\"" "$@"
    '';
in

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.tmp.cleanOnBoot = true;

  # zfs
  systemd.services.zfs-mount.enable = false;
  networking.hostId = "ad26d962";

  # console keymap
  console.keyMap = "us";
  nixpkgs.config.allowUnfree = true;

  # networking
  networking.hostName = "pollux"; # Define your hostname.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "Europe/London";

#  # system auto upgrade
#  system.autoUpgrade = {
#      enable = true;
#      dates = "daily";
#      allowReboot = false;
#  };

  # nix garbage collection
  nix = {
    settings.auto-optimise-store = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8";
    LC_MEASUREMENT = "en_GB.UTF-8";
    LC_MONETARY = "en_GB.UTF-8";
    LC_NAME = "en_GB.UTF-8";
    LC_NUMERIC = "en_GB.UTF-8";
    LC_PAPER = "en_GB.UTF-8";
    LC_TELEPHONE = "en_GB.UTF-8";
    LC_TIME = "en_GB.UTF-8";
  };

  # nix flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # --- XDG Desktop Portal Configuration for Wayland ---
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true; # Recommended for better portal integration
    wlr.enable = true;       # This is the crucial part for wlroots compositors
  };

  # Enable the X11 windowing system.
  services = { 
    system76-scheduler.enable = true;
    xserver = { 
    enable = true;

    videoDrivers = [ "nvidia" ];

    # xkb
    xkb = {
      layout = "gb";
      variant = "mac";
      };
    };

    # gnome
    #displayManager.gdm.enable = true;
    #desktopManager.gnome.enable = true;

    # Enable the COSMIC login manager
    displayManager.cosmic-greeter.enable = true;
  
    # Enable the COSMIC desktop environment
    desktopManager.cosmic.enable = true;

    enviroment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = 1;
    
    zfs.autoScrub.enable = true;
    znapzend = {
      enable = true;
      autoCreation = true;
      pure = true;
      zetup = {
          "zpool/home" = {
            recursive = true;
            mbuffer.enable = true;
            plan = "1h=>1h,1d=>1h,1w=>1d,1m=>1w"; # Take snapshots every hour
          };
        };
      };

    fwupd.enable = true;
    thermald.enable = true;
    openssh.enable = true;
    printing.enable = false;
    libinput.enable = true;

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
   };

    # gnome
    #gnome = {
    #  localsearch.enable = false;
    #};
};


hardware = {
  nvidia.open = false;
  graphics ={
    enable = true;
    extraPackages = with pkgs; [
      intel-vaapi-driver
      libva-vdpau-driver
      libvdpau-va-gl
    ];
  };
};
  
# Enable common container config files in /etc/containers
hardware.nvidia-container-toolkit.enable = true;

# containers registries
virtualisation = {
  containers = {
  enable = true;
  registries.search = [
  "docker.io"
  "quay.io"
  ];
    storage.settings = {
      storage = {
        driver = "zfs";
        graphroot = "/var/lib/containers/storage";
        runroot = "/run/containers/storage";
      };
    };
  };
  podman = {
    enable = true;

    # Create a `docker` alias for podman, to use it as a drop-in replacement
    dockerCompat = true;

    # Required for containers under podman-compose to be able to talk to each other.
    defaultNetwork.settings.dns_enabled = true;
    };
};


# podman zfs
fileSystems."/var/lib/containers/storage" = {
  device = "zpool/containers";
  fsType = "zfs";
  options = [ "zfsutil" ];
};


# users
users.mutableUsers = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
users.users.djwilcox = {
    isNormalUser = true;
    extraGroups = [ "wheel networkmanager audio video oci" ]; # Enable ‘sudo’ for the user.
};

programs = {
  # dwl
  dwl = {
    enable = true;
    # Tell the dwl module to use our wrapper script as the dwl executable
    package = dwlWithDwlbWrapper;
  };

  zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
  };
  dconf.enable = true;
  #ssh.startAgent = true;


  mtr.enable = true;
  gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
};

users.users.djwilcox.shell = pkgs.zsh;
#enviroment.pathsToLink = [ "/share/zsh" ];
#enviroment.shells = with pkgs; [ zsh ];

security.sudo.enable = true;

# rtkit for audio
security.rtkit.enable = true;

# pam setting for audio
security.pam.loginLimits = [
  { domain = "@audio"; item = "memlock"; type = "-"; value = "unlimited"; }
  { domain = "@audio"; item = "rtprio"; type = "-"; value = "99"; }
  { domain = "@audio"; item = "nofile"; type = "soft"; value = "99999"; }
  { domain = "@audio"; item = "nofile"; type = "hard"; value = "99999"; }
];


# doas
security.doas = {
  enable = true;
  extraConfig = ''
    # allow user
    permit keepenv setenv { PATH } djwilcox
    
    # allow root to switch to our user
    permit nopass keepenv setenv { PATH } root as djwilcox

    # nopass
    permit nopass keepenv setenv { PATH } djwilcox

    # nixos-rebuild switch
    permit nopass keepenv setenv { PATH } djwilcox cmd nixos-rebuild
    
    # root as root
    permit nopass keepenv setenv { PATH } root as root
  '';
};

  # gnome remove packages
#  environment.gnome.excludePackages = (with pkgs; [
#    gnome-photos
#    gnome-tour
#    gnome-text-editor
#  ]) ++ (with pkgs; [
#    cheese # webcam tool
#    gnome-calendar
#    gnome-contacts
#    gnome-clocks
#    gnome-music
#    gnome-maps
#    epiphany # web browser
#    geary # email reader
#    gnome-characters
#    gnome-weather
#    simple-scan
#    totem # video player
#  ]);

  # List packages installed in system profile. To search, run:
  # The programs.dwl module creates its own dwl.desktop,
  # which will now correctly launch our wrapper script.
  environment.systemPackages = with pkgs; lib.filter (p: ! (lib.hasAttr "providedSessions" p && p.providedSessions == [ "dwl" ])) [
  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.

  #dwl
  dwlb 
  xdg-desktop-portal-wlr
  # podman
  podman-compose
];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # transmission ports 6881 6882
  # searxng port 8080
  # open-webui port 3000
  # invidious port 3000 8282
  # n8n port 5678
  # crawl4ai 11235
  networking.firewall.allowedTCPPorts = [ 6881 8080 3000 8282 5678 11235 ];
  networking.firewall.allowedUDPPorts = [ 6882 ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  #system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.05"; # Did you read the comment?

}
