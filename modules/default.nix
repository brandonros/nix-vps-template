# Vultr VPS module (hardware + runtime)
{ ... }: {
  imports = [
    ./hardware.nix
    ./runtime.nix
  ];
}
