#===============================================================================
# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
#===============================================================================


#===============================================================================
# config, lib, pkgs
#===============================================================================

{ config, lib, pkgs, ... }:


#===============================================================================
# dwl
#===============================================================================

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


#===============================================================================
# import - hardware-configuration.nix
#===============================================================================

imports =
  [
    ./hardware-configuration.nix
  ];


#===============================================================================
# boot
#===============================================================================

boot = {
  # clean tmp on boot
  tmp.cleanOnBoot = true;

  # extraModprobeConfig for mac vm
  extraModprobeConfig = ''
    options kvm_intel nested=1
    options kvm_intel emulate_invalid_guest_state=0
    options kvm ignore_msrs=1
  '';

  # use the systemd-boot EFI boot loader.
  loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # needed for virt-manager
  kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
  };
};


#===============================================================================
# nix 
#===============================================================================

nix = {
  settings = {
    # auto-optimise-store
    auto-optimise-store = true;
    # flakes
    experimental-features = [ "nix-command" "flakes" ];
  };

  # nix garbage collection
  gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
};


#===============================================================================
# nixpkgs
#===============================================================================

nixpkgs.config.allowUnfree = true;


#===============================================================================
# console keymap
#===============================================================================

console.keyMap = "us";


#===============================================================================
# time zone
#===============================================================================

time.timeZone = "Europe/London";


#===============================================================================
# environment.sessionVariables - comsic clipboard
#===============================================================================

environment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = 1;


#===============================================================================
# Select internationalisation properties.
#===============================================================================

i18n = {
  defaultLocale = "en_GB.UTF-8";
  extraLocaleSettings = {
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
};


#===============================================================================
# users
#===============================================================================

users = {
  mutableUsers = true; # mutable user set a password with ‘passwd’

  # user
  users.djwilcox = {
    shell = pkgs.zsh; # shell
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "audio" "video" "oci" "libvirtd" ];
  };
};


#===============================================================================
# hardware graphics
#===============================================================================

hardware = {
  nvidia.open = false; # proprietary nvidia drivers
  nvidia-container-toolkit.enable = true; # nvidia container toolkit
  graphics ={
    enable = true;
    extraPackages = with pkgs; [
      intel-vaapi-driver
      libva-vdpau-driver
      libvdpau-va-gl
    ];
  };
};


#===============================================================================
# systemd.services
#===============================================================================

systemd = {
  services = {
    zfs-mount.enable = false; # zfs mount
    unbound.wants = [ "dnscrypt-proxy.service" ]; # unbound wants dnscrypt
    unbound.after = [ "dnscrypt-proxy.service" ]; # unbound after dnscrypt
  };
};


#===============================================================================
# filesystems
#===============================================================================

# libvirt zfs mount
fileSystems."/home/djwilcox/libvirt" = {
  device = "zpool/home/libvirt";
  fsType = "zfs";
  options = [ "zfsutil" ];
};


# podman zfs
fileSystems."/var/lib/containers/storage" = {
  device = "zpool/containers";
  fsType = "zfs";
  options = [ "zfsutil" ];
};


#===============================================================================
# services
#===============================================================================

services = { 
   usbmuxd.enable = true; # for ios

   # avahi for airplay
   avahi = {
     enable = true;
     nssmdns4 = true;
     publish = {
       enable = true;
       userServices = true;
     };
   };

   dbus.packages = [ pkgs.xdg-desktop-portal-cosmic ]; # dbus
   system76-scheduler.enable = true; # cosmic scheduler
   spice-vdagentd.enable = true;      # Guest agent for SPICE (copy/paste, etc.)

   # xserver
   xserver = { 
   enable = true;
   videoDrivers = [ "nvidia" ];

   # xkb
   xkb = {
     layout = "gb";
     variant = "mac";
     };
   };

   # Enable the COSMIC login manager
   displayManager.cosmic-greeter.enable = true;

   # In configuration.nix under services
   displayManager.sessionPackages = lib.mkForce [
     (pkgs.runCommand "dwl-session" {
       passthru.providedSessions = [ "dwl" ];
     } ''
       mkdir -p $out/share/wayland-sessions
       cat <<EOF > $out/share/wayland-sessions/dwl.desktop
       [Desktop Entry]
       Name=dwl
       Comment=Dynamic window manager for Wayland (Forced wayland-0)
       Exec=env WAYLAND_DISPLAY=wayland-0 XDG_CURRENT_DESKTOP=dwl ${lib.getExe dwlWithDwlbWrapper}
       Type=Application
       EOF
     '')
   ];

   # Enable the COSMIC desktop environment
   desktopManager.cosmic.enable = true;

   # zfs auto scrub
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

   openssh.enable = true; # ssh
   fwupd.enable = true;
   thermald.enable = true;
   printing.enable = false; # disable cups printing
   libinput.enable = true;  # libinput - touchpad

   # pipewire
   pipewire = {
     enable = true;
     alsa.enable = true;
     alsa.support32Bit = true;
     pulse.enable = true;
     jack.enable = true;
  };

   # dnscrypt
   dnscrypt-proxy = {
     enable = true;
     settings = {
       require_dnssec = true;
       require_nolog = true;
       require_nofilter = true;
       listen_addresses = [ "127.0.0.1:5300" ];

       sources.public-resolvers = {
       urls = [
         "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md"
         "https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md"
       ];
       cache_file = "/var/cache/dnscrypt-proxy/public-resolvers.md";
       minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
       };
     };
  };

   # unbound
   unbound = {
     enable = true;

     settings = {
       server = {
          do-not-query-localhost = false;
          interface = [ "127.0.0.1" "10.200.1.1" ];
          port = 53;
          access-control = [ "127.0.0.0/8 allow" "10.200.1.0/24 allow" ];
          module-config = ''"validator iterator"'';
       };
       # Forward all queries to dnscrypt-proxy
       forward-zone = [
         {
           name = ".";
           forward-addr = [ "127.0.0.1@5300" "9.9.9.9" "1.4.1.1" ];
         }
       ];
     };
   };
};


#===============================================================================
# security 
#===============================================================================

security = {
  sudo.enable = true;  # sudo
  rtkit.enable = true; # rtkit for audio

  # pam setting for audio
  pam.loginLimits = [
    { domain = "@audio"; item = "memlock"; type = "-"; value = "unlimited"; }
    { domain = "@audio"; item = "rtprio"; type = "-"; value = "99"; }
    { domain = "@audio"; item = "nofile"; type = "soft"; value = "99999"; }
    { domain = "@audio"; item = "nofile"; type = "hard"; value = "99999"; }
  ];

  # doas
  doas = {
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
};


#===============================================================================
# networking
#===============================================================================

networking = {
  # dns
  nameservers = [ "127.0.0.1" ];
  networkmanager.dns = "none";

  hostName = "pollux"; # Define your hostname.
  hostId = "ad26d962"; # hostid
  networkmanager.enable = true;  # network manager

  # dummy network interface
  networkmanager.ensureProfiles.profiles = {
    dummy0 = {
      connection = {
        id = "dummy0";
        type = "dummy";
        interface-name = "dummy0";
      };
      ipv4 = {
        address1 = "10.200.1.1/24";
        method = "manual";
      };
    };
  };


  # dummy network interface
  interfaces.dummy0 = {
    ipv4.addresses = [ { address = "10.200.1.1"; prefixLength = 24; } ];
  };


  # firewall
  # Open ports in the firewall.
  # transmission ports 6881 6882
  # searxng port 8080
  # open-webui port 3000
  # invidious port 3000 8282
  # n8n port 5678
  # crawl4ai 11235
  # for ios airplay - allowedTCPPorts = [ 7000 7001 7100 ];
  # for ios airplay - allowedUDPPorts = [ 5353 6000 6001 7011 ];

  firewall = {
  # allowedTCPPorts
  allowedTCPPorts = [ 6881 8080 3000 7000 7001 7100 8282 5678 11235 ];

  # allowedUDPPorts
  allowedUDPPorts = [ 5353 6000 6001 6882 7011 ];

  # uxplay ports
  allowedTCPPortRanges = [ { from = 32768; to = 61000; } ];
  allowedUDPPortRanges = [ { from = 32768; to = 61000; } ];

  # trust the virbr0 veth-host dummy0 interfaces 
  trustedInterfaces = [
    "virbr0"
    "veth-host"
    "dummy0"
    "tap0"
    "vnet0"
  ]; 

  # needed for virt-manager
  checkReversePath = false;
  extraCommands = ''
      iptables -A FORWARD -i virbr0 -j ACCEPT
      iptables -A FORWARD -o virbr0 -j ACCEPT
    '';
  };
};


#===============================================================================
# XDG Desktop Portal Configuration for Wayland
#===============================================================================

xdg.portal = {
  enable = true;

  # This replaces the old 'wlr.enable = true' logic with a more robust version
  extraPortals = [ 
    pkgs.xdg-desktop-portal-wlr 
    pkgs.xdg-desktop-portal-cosmic
    pkgs.xdg-desktop-portal-gtk
  ];

  config = {
    # Default for all sessions
    common.default = [ "gtk" ];
    
    # Specific override for your COSMIC session
    cosmic.default = [ "cosmic" ];

    # Specific override for your dwl session
    dwl.default = [ "wlr" ];
  };
};


#===============================================================================
# programs
#===============================================================================

programs = {
  # dwl
  dwl = {
    enable = true;
    # Tell the dwl module to use our wrapper script as the dwl executable
    package = dwlWithDwlbWrapper;
  };

  # zsh shell
  zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
  };

  # dconf
  dconf.enable = true;

  # mtr
  mtr.enable = true;

  gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
};


#===============================================================================
# systemPackages
#===============================================================================

  environment.systemPackages = with pkgs; lib.filter (p: ! (lib.hasAttr "providedSessions" p && p.providedSessions == [ "dwl" ])) [
  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.

  #dwl
  dwlb 
  xdg-desktop-portal-wlr
  xdg-desktop-portal-cosmic

  # podman
  podman-compose

  # for ios
  libimobiledevice 
  ifuse
  uxplay
  gst_all_1.gst-plugins-good
  gst_all_1.gst-plugins-bad
  gst_all_1.gst-plugins-ugly
  gst_all_1.gst-libav
];


#===============================================================================
# virtualisation
#===============================================================================

virtualisation = {
  containers = {
  enable = true;

  # podman registries
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

  # podman
  podman = {
    enable = true;

    # Create a `docker` alias for podman
    dockerCompat = true;

    # Required for containers under podman-compose to be able to talk to each other.
    defaultNetwork.settings.dns_enabled = true;
    };

   # libvirt
    libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;
        swtpm.enable = true; # Required for Windows 11 TPM
        vhostUserPackages = [ pkgs.virtiofsd ];
      };
    };
    spiceUSBRedirection.enable = true;
};


#===============================================================================
# system.stateVersion
#===============================================================================

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
