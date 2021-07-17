#!/bin/sh

echo
echo "Installing Operating System dependencies"
echo 

sudo apt-get update -y
sudo apt-get install automake build-essential pkg-config libffi-dev libgmp-dev libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev make g++ tmux git jq wget libncursesw5 libtool autoconf -y;

echo
echo "Checking for ghcup"
echo

if ! type ghcup > /dev/null; then
    echo
    echo "Installing GHC"
    echo 
    curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
    echo
    echo "Installing GHC 8.10.4"
    echo
    ghcup install ghc 8.10.4
    ghcup set ghc 8.10.4
    exit 1
fi

ghc --version;
cabal --version;

if [ -d ~/cardano ];
then
    echo
    echo "Cleaning up..."
    echo
    rm -rf ~/cardano
fi;

echo 
echo "Downloading libsodium to ~/cardano-src"
echo

mkdir -p ~/cardano
cd ~/cardano || exit 
git clone https://github.com/input-output-hk/libsodium
cd libsodium || exit
git checkout 66f017f1
./autogen.sh
./configure
make
sudo make install

echo
echo "Adding libsodium compiler to PATH and sourcing ~/.bashrc"
echo 'export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"' >> "$HOME"/.bashrc
echo 'export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"' >> "$HOME"/.bashrc
echo 'export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"' >> "$HOME"/.zshrc
echo 'export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"' >> "$HOME"/.zshrc
echo

. "$HOME"/.bashrc

echo
echo "Downloading cardano-node repository to ~/cardano"
echo

node_version=$(curl -s https://api.github.com/repos/input-output-hk/cardano-node/releases/latest | grep '"tag_name":' |  sed -E 's/.*"([^"]+)".*/\1/')

cd ~/cardano || exit 
git clone https://github.com/input-output-hk/cardano-node.git
cd cardano-node || exit
git checkout tags/"${node_version}"

echo
echo "Configuring the build options to build with GHC version 8.10.4"
echo

cabal configure --with-compiler=ghc-8.10.4

echo
echo "Update the local project file to use libsodium"
echo
echo "package cardano-crypto-praos" >>  cabal.project.local
echo "  flags: -external-libsodium-vrf" >>  cabal.project.local

echo
echo "Building and installing the node to produce executables binaries"
echo

cabal build all

echo
echo "Installing the binaries to ~/.local/bin"
echo

mkdir -p "$HOME"/.local/bin
cp -p "$(./scripts/bin-path.sh cardano-node)" "$HOME"/.local/bin/
cp -p "$(./scripts/bin-path.sh cardano-cli)" "$HOME"/.local/bin/

echo
echo "Adding ~/.local/bin to PATH"
echo
echo 'export PATH="$HOME/.local/bin/:$PATH"' >> "$HOME"/.bashrc
echo 'export PATH="$HOME/.local/bin/:$PATH"' >> "$HOME"/.zshrc
echo
echo "Sourcing ~/.bashrc"
echo

. "$HOME"/.bashrc

echo
echo "Checking versions of the binaries"
echo

cardano-cli --version
cardano-node --version