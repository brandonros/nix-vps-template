# Runtime config shared between base image and rebuild targets
# No boot/filesystem config - those differ between image build and final system
{ sshPubKey, hostname ? "nixos-vps", ... }: {
  # Network
  networking.hostName = hostname;
  networking.useDHCP = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  # Users - SSH key only, no passwords
  users.users.root.openssh.authorizedKeys.keys = [ sshPubKey ];
  users.users.user = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ sshPubKey ];
  };

  # SSH
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "prohibit-password";
    settings.PasswordAuthentication = false;
  };

  # Sudo without password
  security.sudo.wheelNeedsPassword = false;

  # Nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "23.11"; # nixos-infect version?
}
