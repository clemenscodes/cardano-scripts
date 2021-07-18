#!/bin/env bash

workdir="$HOME/cardano"
RED='\033[0;31m'    
GREEN='\033[0;32m'    
SET='\033[0m'

update() {
    echo -e "${GREEN}Updating and installing Operating System dependencies${SET}"
    sudo apt-get update -y
}

install_debian_os_packages() {
    sudo apt-get install automake build-essential pkg-config libffi-dev libgmp-dev libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev make g++ tmux git jq wget libncursesw5 libtool autoconf -y;
}

install_nix() {
    echo -e "${RED}Nix is not installed, proceeding to install Nix${SET}"
    curl -L https://nixos.org/nix/install > install-nix.sh
    chmod +x install-nix.sh
    ./install-nix.sh
}

set_nix_iohk_build_cache() 
{
echo -e "${GREEN}Setting IOHK Build Cache${SET}"
sudo mkdir -p /etc/nix
cat <<EOF | sudo tee /etc/nix/nix.conf
substituters = https://cache.nixos.org https://hydra.iohk.io
trusted-public-keys = iohk.cachix.org-1:DpRUyj7h7V830dp/i6Nti+NEO2/nhblbov/8MW7Rqoo= hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
EOF
}

check_nix() {
    echo -e "${GREEN}Checking for Nix${SET}"
    if ! type nix > /dev/null; 
    then
        install_nix
        set_nix_iohk_build_cache
    fi
}

install_ghcup() {
    echo -e "${GREEN}Installing GHC${SET}"
    curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
}

check_ghcup() {

    echo -e "${GREEN}Checking for ghcup${SET}"
    if ! type ghcup > /dev/null
    then
        install_ghcup
    fi
}

install_ghc() {
    echo -e "${GREEN}Installing GHC 8.10.4${SET}"
    ghcup install ghc 8.10.4
    ghcup set ghc 8.10.4
}

check_ghc() {
    echo -e "${GREEN}Checking for GHC${SET}"
    if ! type ghc > /dev/null
    then 
        install_ghc
    fi 
}

check_cabal() {
    echo -e "${GREEN}Checking for Cabal${SET}"
    if ! type cabal > /dev/null
        then 
        echo -e "${RED}Cabal is not installed properly${SET}"
        install_ghcup  
    fi 
}

check_dependencies() {
    install_debian_os_packages
    check_nix
    check_ghcup
    check_ghc
    check_cabal
}

clean_up_workdir() {
    echo -e "${RED}Cleaning up working directory...${SET}"
    rm -rf "$workdir"
}

create_workdir() {
    echo -e "${GREEN}Creating working directory in $workdir${SET}"
    mkdir -p "$workdir" 
    cd "$workdir" || exit 
}

check_existing_workdir() {
    echo -e "${GREEN}Checking for existing working directory in $workdir${SET}"
    if [ -d "$workdir" ];
    then
        clean_up_workdir
        create_workdir
    fi
}

download_libsodium() {
    echo -e "${GREEN}Downloading libsodium to $workdir${SET}"
    git clone https://github.com/input-output-hk/libsodium
}

install_libsodium() {
    download_libsodium
    echo -e "${GREEN}Installing libsodium to $workdir${SET}"
    cd libsodium || exit
    git checkout 66f017f1
    ./autogen.sh
    ./configure
    make
    sudo make install
}

source_bashrc() {
    echo -e "${GREEN}Sourcing $HOME/.bashrc${SET}"
    . "$HOME"/.bashrc
}

add_ld_to_bashrc() {
    echo -e "${GREEN}Adding libsodium compiler to $HOME/.bashrc${SET}"
    echo 'export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"' >> "$HOME"/.bashrc
}

check_ld_in_bashrc() {
    ld_in_bashrc=$(grep LD_LIBRARY_PATH "$HOME"/.bashrc)
    if [ -z "${ld_in_bashrc}" ]
    then 
        add_ld_to_bashrc
        source_bashrc
    fi 
}

add_ld_to_zshrc() {
    echo -e "${GREEN}Adding libsodium compiler to $HOME/.zshrc${SET}"
    echo 'export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"' >> "$HOME"/.zshrc
}

check_ld_in_zshrc() {
    ld_in_zshrc=$(grep LD_LIBRARY_PATH "$HOME"/.zshrc)
    if [ -z "${ld_in_zshrc}" ]
    then 
        add_ld_to_zshrc
    fi 
}

add_pkg_to_bashrc() {
    echo -e "${GREEN}Adding package config path to $HOME/.bashrc${SET}"
    echo 'export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"' >> "$HOME"/.bashrc
}

check_pkg_in_bashrc() {
    pkg_in_bashrc=$(grep PKG_CONFIG_PATH "$HOME"/.bashrc)
    if [ -z "${pkg_in_bashrc}" ]
        then 
        add_pkg_to_bashrc
        source_bashrc
    fi 
}

add_pkg_to_zshrc() {
    echo -e "${GREEN}Adding package config path to $HOME/.zshrc${SET}"
    echo 'export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"' >> "$HOME"/.zshrc
}

check_pkg_in_zshrc() {
    pkg_in_zshrc=$(grep PKG_CONFIG_PATH "$HOME"/.zshrc)
    if [ -z "${pkg_in_zshrc}" ]
        then 
        add_pkg_to_zshrc
    fi 
}

check_libsodium_path_env() {
    check_ld_in_bashrc
    check_pkg_in_bashrc
    check_ld_in_zshrc
    check_pkg_in_zshrc
}

download_cardano_node_repository() {
    echo -e "${GREEN}Downloading Cardano Node Repository${SET}"
    git clone https://github.com/input-output-hk/cardano-node.git
}

download_cardano_db_sync_repository() {
    echo -e "${GREEN}Downloading Cardano DB Sync Repository${SET}"
    git clone https://github.com/input-output-hk/cardano-db-sync.git
}

create_db_folder() {
    echo -e "${GREEN}Adding db folder to working directory${SET}"
    mkdir -p "$workdir"/db
}

download_cardano_repositories_to_workdir() {
    cd "$workdir" || exit 
    download_cardano_node_repository
    download_cardano_db_sync_repository
    create_db_folder
}

checkout_latest_node_version() {
    cd cardano-node || exit
    echo -e "${GREEN}Fetching latest node version${SET}"
    latest_node_version=$(curl -s https://api.github.com/repos/input-output-hk/cardano-node/releases/latest | grep '"tag_name":' |  sed -E 's/.*"([^"]+)".*/\1/')
    git checkout tags/"${latest_node_version}"
}

configure_build_options() {
    echo -e "${GREEN}Configuring the build options to build with GHC version 8.10.4${SET}"
    cabal configure --with-compiler=ghc-8.10.4
}

update_local_project_file_to_use_libsodium_compiler() {
    echo -e "${GREEN}Update the local project file to use libsodium${SET}"
    echo "package cardano-crypto-praos" >>  cabal.project.local
    echo "  flags: -external-libsodium-vrf" >>  cabal.project.local
}

build_latest_node_version() {
    install_libsodium
    check_libsodium_path_env
    download_cardano_repositories_to_workdir
    checkout_latest_node_version
    configure_build_options
    update_local_project_file_to_use_libsodium_compiler
    echo -e "${GREEN}Building and installing the node to produce executables binaries${SET}"
    cabal build all
}

check_for_binary_install_directory() {
    if ! [ -d "$HOME"/.local/bin ]
        then 
        mkdir -p "$HOME"/.local/bin
    fi
}

add_local_bin_to_bashrc() {
    echo -e "${GREEN}Adding ~/.local/bin to $HOME/.bashrc${SET}"
    echo 'export PATH="$HOME/.local/bin/:$PATH"' >> "$HOME"/.bashrc
}

check_for_local_bin_in_bashrc() {
    echo -e "${GREEN}Checking for $HOME/.local/bin in $HOME/.bashrc${SET}"
    local_bin_in_bashrc=$(grep "$HOME/.local/bin/" "$HOME"/.bashrc)
    if [ -z "${local_bin_in_bashrc}" ]
        then 
        add_local_bin_to_bashrc
        source_bashrc
    fi 
}

add_local_bin_to_zshrc() {
    echo -e "${GREEN}Adding $HOME/.local/bin to $HOME/.zshrc${SET}"
    echo 'export PATH="$HOME/.local/bin/:$PATH"' >> "$HOME"/.zshrc
}

check_for_local_bin_in_zshrc() {
    echo -e "${GREEN}Checking for $HOME/.local/bin in $HOME/.zshrc${SET}"
    local_bin_in_zshrc=$(grep "$HOME/.local/bin/" "$HOME"/.zshrc)
    if [ -z "${local_bin_in_zshrc}" ]
        then 
        add_local_bin_to_zshrc
    fi 
}

check_local_bin_in_path() {
    check_for_local_bin_in_bashrc
    check_for_local_bin_in_zshrc
}

installing_binaries_to_local_bin() {
    echo -e "${GREEN}Installing the binaries to $HOME/.local/bin${SET}"
    check_for_binary_install_directory
    cp -p "$(./scripts/bin-path.sh cardano-node)" "$HOME"/.local/bin/
    cp -p "$(./scripts/bin-path.sh cardano-cli)" "$HOME"/.local/bin/
    check_local_bin_in_path
}

check_cardano_cli_installation() {
    echo -e "${GREEN}Checking Cardano CLI installation${SET}"
    if ! type cardano-cli > /dev/null
        then 
        echo -e "${RED}Failed installing cardano-cli${SET}"
        exit 1
        else
        echo -e "${GREEN}Successfully installed cardano-cli${SET}"
    fi
}

check_cardano_node_installation() {
    echo -e "${GREEN}Checking Cardano Node installation${SET}"
    if ! type cardano-node > /dev/null
        then 
        echo -e "${RED}Failed installing cardano-node${SET}"
        exit 1
        else
        echo -e "${GREEN}Successfully installed cardano-node${SET}"
    fi
}

check_installation() {
    echo -e "${GREEN}Checking binaries${SET}"
    check_cardano_cli_installation
    check_cardano_node_installation
}

run() {
    echo -e "${GREEN}This script will install Cardano Node and its components to $HOME/cardano${SET}"
    update
    check_dependencies
    check_existing_workdir
    build_latest_node_version
    installing_binaries_to_local_bin
    check_installation
}

run