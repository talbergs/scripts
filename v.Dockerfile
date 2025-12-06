FROM nixos/nix

RUN nix-channel --update

RUN nix-build -A cowsay '<nixpkgs>'
