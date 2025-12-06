{ pkgs ? import <nixpkgs> { system = "aarch64-linux"; } }:

pkgs.stdenv.mkDerivation {
  name = "neovim-docker-env";

  buildInputs = with pkgs; [
    neovim
    git
    ripgrep
    fd
    nodejs
    gcc
  ];

  buildCommand = ''
    mkdir -p $out/bin
    mkdir -p $out/config

    # Create wrapper script that sets up neovim with config
    cat > $out/bin/nvim-docker << 'EOF'
#!/bin/sh
export XDG_CONFIG_HOME=/config
mkdir -p /config/nvim
if [ -f /config/nvim/init.lua ]; then
  exec ${pkgs.neovim}/bin/nvim "$@"
else
  echo "Warning: /config/nvim/init.lua not found"
  exec ${pkgs.neovim}/bin/nvim "$@"
fi
EOF
    chmod +x $out/bin/nvim-docker

    # Also provide direct access to nvim
    ln -s ${pkgs.neovim}/bin/nvim $out/bin/nvim
  '';

  meta = {
    description = "Neovim environment for Docker container";
    platforms = [ "aarch64-linux" ];
  };
}
