# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

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
  # unfree set in flake.nix
  # nixpkgs.config.allowUnfree = true;

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

  # Enable the X11 windowing system.
  services = { 
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
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
    
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
    gnome = {
      localsearch.enable = false;
    };
};


hardware = {
  nvidia.open = false;
  graphics ={
    enable = true;
    extraPackages = with pkgs; [
      vaapiIntel
      vaapiVdpau
      libvdpau-va-gl
    ];
  };
};
  


# users
users.mutableUsers = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
users.users.djwilcox = {
    isNormalUser = true;
    extraGroups = [ "wheel networkmanager audio video" ]; # Enable ‘sudo’ for the user.
};


programs = {
  # dwl
  dwl = {
    enable = true;
    # Crucially, tell the module to use YOUR customized dwl package
    package = pkgs.dwl;
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
  environment.gnome.excludePackages = (with pkgs; [
    gnome-photos
    gnome-tour
    gnome-text-editor
  ]) ++ (with pkgs; [
    cheese # webcam tool
    gnome-calendar
    gnome-contacts
    gnome-clocks
    gnome-music
    gnome-maps
    epiphany # web browser
    geary # email reader
    gnome-characters
    gnome-weather
    simple-scan
    totem # video player
  ]);

  # List packages installed in system profile. To search, run:
  # $ nix search wget
environment.systemPackages = with pkgs; [
  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.

  #dwl # dwl
  # dwlb # Assuming dwlb is a separate package you need
  tofi
  wlrctl
  wlr-which-key

 # Corrected way to install the dwl.desktop file
 (stdenv.mkDerivation {
   pname = "dwl-desktop-entry";
   version = "1.0";

   # The actual desktop file content
   desktopFile = writeText "dwl.desktop" ''
     [Desktop Entry]
     Name=dwl
     Comment=Dynamic Wayland Window Manager
     Exec=dbus-launch --exit-with-session dwl -s '${pkgs.dwlb}/bin/dwlb -font "monospace:size=16"'
     Type=Application
     Keywords=wayland;tiling;windowmanager;
     DesktopNames=dwl
     NoDisplay=false
   '';

   # Crucial: Tell stdenv to skip unnecessary phases
   dontUnpack = true;
   dontBuild = true;
   dontConfigure = true;

   # This phase tells Nix to copy the desktopFile to the correct location
   installPhase = ''
     mkdir -p $out/share/xsessions
     cp $desktopFile $out/share/xsessions/dwl.desktop
   '';
 })
];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 6881 ];
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
