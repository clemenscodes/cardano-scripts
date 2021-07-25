#!/bin/sh

WORK_DIR="$HOME/.cardano"
CARDANO_NODE_DIR="$WORK_DIR/cardano-node"
BIN_PATH="$CARDANO_NODE_DIR/scripts/bin-path.sh"
CARDANO_DB_SYNC_DIR="$WORK_DIR/cardano-db-sync"
PROJECT_FILE="$CARDANO_NODE_DIR/cabal.project.local"
INSTALL_DIR="$HOME/.local/bin"
IPC_DIR="$WORK_DIR/ipc"
CONFIG_DIR="$WORK_DIR/config"
DATA_DIR="$WORK_DIR/data/db"
MAINNET_DATA_DIR="$DATA_DIR/mainnet"
TESTNET_DATA_DIR="$DATA_DIR/testnet"
LIBSODIUM_DIR="$WORK_DIR/libsodium"
CLI_BINARY="$INSTALL_DIR/cardano-cli"
NODE_BINARY="$INSTALL_DIR/cardano-node"
GHC_VERSION="8.10.4"
CABAL_VERSION="3.4.0.0"
PLATFORM="$(uname -s)"
DISTRO="$(cat /etc/*ease | grep "DISTRIB_ID" | awk -F '=' '{print $2}')"
RELEASE_URL="https://api.github.com/repos/input-output-hk/cardano-node/releases/latest"
CARDANO_NODE_URL="https://github.com/input-output-hk/cardano-node.git"
CARDANO_DB_SYNC_URL="https://github.com/input-output-hk/cardano-db-sync.git"
LIBSODIUM_URL="https://github.com/input-output-hk/libsodium"
GHCUP_INSTALL_URL="https://get-ghcup.haskell.org"
LATEST_VERSION="$(curl -s "$RELEASE_URL" | grep tag_name | awk -F ':' '{print $2}' | tr -d '"' | tr -d ',' | tr -d '[:space:]')"
LD_LIBRARY="$(cat << 'EOF'
export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"             
EOF
)"
PKG_CONFIG="$(cat << 'EOF'
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"
EOF
)"
CARDANO_NODE_SOCKET="$(cat << 'EOF'
export CARDANO_NODE_SOCKET_PATH="$HOME/.cardano/ipc/node.socket"
EOF
)"
INSTALL_PATH="$(cat << 'EOF'
export PATH="$HOME/.local/bin/:$PATH"
EOF
)"
GHCUP_PATH="$(cat << 'EOF'
export PATH="$HOME/.cabal/bin:$HOME/.ghcup/bin:$PATH"
EOF
)"
WHITE="\\033[1;37m"
GREEN="\\033[0;32m"
RED="\\033[0;31m"
SET="\\033[0m\\n"

white() {
    printf "$WHITE%s$SET" "$1"
}

green() {
    printf "$GREEN%s$SET" "$1"
}

red() {
    printf "$RED%s$SET" "$1"
}

die() {
    red "$1" && exit 1
}

succeed() {
    green "$1" && exit 0
}

check_version() {
    [ -z "$LATEST_VERSION" ] && red "Couldn't fetch latest node version, try again after making sure you have curl installed" && exit 1
    white "Installing the latest cardano-node ($LATEST_VERSION) and its components to $WORK_DIR"
    if type cardano-node >/dev/null 2>&1; then 
        installed_cardano_node_version=$(cardano-node  --version | awk '{print $2}'| head -n1)
        if [ "$installed_cardano_node_version" = "$LATEST_VERSION" ]; then 
            succeed "Already installed latest cardano-node (v$installed_cardano_node_version)"
        else 
            white "Updating cardano-node version $installed_cardano_node_version to version $LATEST_VERSION"
            install_latest_node || die "Failed updating node to $LATEST_VERSION"
        fi
    fi 
}

check_root() {
    white "This script will require root privileges to install the required packages"
    [ "$(id -u)" -ne 0 ] && sudo echo >/dev/null 2>&1
    green "Obtained root privileges"
}

check_directory() {
    white "Checking for $1 directory in $2"
    { ! [ -d "$2" ] && create_directory "$1" "$2"; } || green "$2 directory found, skipped creating"
    green "Checked directory $1 successfully"
}

create_directory() {
    white "Creating directory $1 in $2"
    mkdir -p "$2" || die "Failed creating $1 directory in $2"
    green "Created $1 directory"
}

change_directory() {
    white "Changing directory to $1"
    cd "$1" || die "Failed changing directory to $1"
    green "Successfully changed directory to $1"
}

check_shell() {
    white "Checking for shell"
    case "$SHELL" in
        */zsh)
            SHELL_PROFILE_FILE="$HOME/.zshrc"
            MY_SHELL="zsh" ;;
        */bash)
            SHELL_PROFILE_FILE="$HOME/.bashrc"
            MY_SHELL="bash" ;;
        */sh) 
            if [ -n "$BASH" ]; then
                SHELL_PROFILE_FILE="$HOME/.bashrc"
                MY_SHELL="bash"
            elif [ -n "$ZSH_VERSION" ]; then
                white "Found zsh"
                SHELL_PROFILE_FILE="$HOME/.zshrc"
                MY_SHELL="zsh"
            fi ;;
        *) red "No shell detected exporting environment variables to current shell session only";;
    esac
}

ask_change_shell_run_control() {
    while true; do
        [ -z "$MY_SHELL" ] && return 0
        green "Detected $MY_SHELL"
        white "Do you want to automatically add the required PATH variables to $SHELL_PROFILE_FILE ?"
        white "[y] Yes (default) [n] No [?] Help"
        read -r answer
        case "$answer" in
            [Yy]* | "") green "Proceeding to add PATH variables for $MY_SHELL" && return 1;;
            [Nn]*) red "Skipped adding PATH variables" && return 0;;
            *)
                white "Possible choices are:"
                green "Y - Yes (default)"
                red "N - No, don't mess with my configuration"
                white "Please make your choice and press ENTER.";;
        esac
    done
    unset answer
}

change_shell_run_control() {
    case "$1" in
        1)
            white "Setting path variables if not already set"
            { [ -z "$LD_LIBRARY_PATH" ] && echo "$LD_LIBRARY" >> "$SHELL_PROFILE_FILE"; } || green "LD_LIBRARY_PATH is already set"
            { [ -z "$PKG_CONFIG_PATH" ] && echo "$PKG_CONFIG" >> "$SHELL_PROFILE_FILE"; } || green "PKG_CONFIG_PATH is already set" 
            { [ -z "$CARDANO_NODE_SOCKET_PATH" ] && echo "$CARDANO_NODE_SOCKET" >> "$SHELL_PROFILE_FILE"; } || green "CARDANO_NODE_SOCKET_PATH is already set"
            { echo "$PATH" | grep -q "\.local/bin/" || echo "$INSTALL_PATH" >> "$SHELL_PROFILE_FILE"; } || green "$INSTALL_DIR PATH is already set"
            { echo "$PATH" | grep -q "\.ghcup/bin" || echo "$GHCUP_PATH" >> "$SHELL_PROFILE_FILE"; } || green "GHCup PATH is already set" ;;
        *) 
            white "Exporting variables"
            export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
            export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"
            export CARDANO_NODE_SOCKET_PATH="$HOME/cardano/ipc/node.socket"
            export PATH="$HOME/.local/bin/:$PATH"
            export PATH="$HOME/.cabal/bin:$HOME/.ghcup/bin:$PATH" ;;
    esac
}

check_run_control() {
    check_shell
    ask_change_shell_run_control 
    ask_change_shell_run_control_answer=$? 
    change_shell_run_control $ask_change_shell_run_control_answer
}

setup_packages() {
    white "Setting up required packages"
    { [ -z "$PLATFORM" ] && red "Could not detect platform"; } || green "Detected $PLATFORM"
    { [ -z "$DISTRO" ] && red "Could not detect distribution"; } || green "Detected $DISTRO"
    case "$PLATFORM" in
        "linux" | "Linux")
            case "$DISTRO" in 
                Fedora*|Hat*|CentOs*)
                    package_manager="yum"
                    packages="curl git gcc gcc-c++ tmux gmp-devel make tar xz wget zlib-devel libtool autoconf systemd-devel ncurses-devel ncurses-compat-libs"
                    install_packages "$packages" || die "Failed installing packages" ;;
                Ubuntu*|Debian*)
                    package_manager="apt"
                    packages="curl automake build-essential pkg-config libffi-dev libgmp-dev libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev make g++ tmux git jq wget libncursesw5 libtool autoconf"
                    install_packages "$packages" || die "Failed installing packages" ;;
                *) die "Unsupported distribution" 
            esac ;;
        *) die "Unsupported platform"
    esac
    green "Successfully setup packages"
}

install_packages() {
    white "Updating"
    sudo "$package_manager" update -y >/dev/null 2>&1
    white "Installing $DISTRO dependencies" 
    for package in $1
    do
        check_package "$package_manager" "$package"
    done
    green "Successfully installed packages"
}

check_package() {
    white "Checking for $2"
    case "$1" in
        apt) 
            pkg_installed="$(dpkg -s "$2" 2>/dev/null | grep "install ok installed")"
            { [ -z "$pkg_installed" ] && install_package "$1" "$2"; } || green "$2 is installed";;
        yum)
            { rpm -q "$2" >/dev/null 2>&1 && green "$2 is installed"; } || install_package "$1" "$2";;
    esac
}

install_package() {
    red "$2 is not installed"
    white "Installing $2"  
    sudo "$1" install "$2" >/dev/null 2>&1 || red "Failed installing $2"
    green "Installed $2"
}

prepare_build() {
    white "Preparing build"
    check_dependencies 
    setup_workdir
    install_libsodium
    green "Prepared build"
}

check_dependencies() {
    white "Checking dependencies"
    check_ghcup 
    check_ghc 
    check_cabal
    green "Successfully installed dependencies"
}

check_ghcup() {
    white "Checking for ghcup"
    { ! type ghcup > /dev/null 2>&1 && install_ghcup; } || green "$(ghcup --version)"
}

install_ghcup() {
    ({ white "Installing ghcup" &&
    export BOOTSTRAP_HASKELL_NONINTERACTIVE=1 &&
    export BOOTSTRAP_HASKELL_GHC_VERSION="$GHC_VERSION" &&
    export BOOTSTRAP_HASKELL_CABAL_VERSION="$CABAL_VERSION" &&
    curl --proto '=https' --tlsv1.2 -sSf "$GHCUP_INSTALL_URL" | sh >/dev/null 2>&1; } || die "Failed installing ghcup")
    export PATH="$HOME/.cabal/bin:$HOME/.ghcup/bin:$PATH"
    green "Installed ghcup"
}

check_ghc() {
    white "Checking for GHC"
    if ! type ghc > /dev/null 2>&1; then 
        install_ghc
    elif [ "$(ghc --version | awk '{print $8}')" != "$GHC_VERSION" ]; then
        export PATH="$HOME/.cabal/bin:$HOME/.ghcup/bin:$PATH"
        installed_ghc=$(ghc --version | awk '{print $8}')
        red "Currently GHC $installed_ghc is installed, removing it and installing desired version $GHC_VERSION"
        ghcup rm ghc "$installed_ghc" >/dev/null 2>&1
        install_ghc >/dev/null 2>&1
        white "$(ghc --version)"
    else 
        green "$(ghc --version)"
    fi 
}

install_ghc() {
    white "Installing GHC $GHC_VERSION"
    ! type ghcup >/dev/null 2>&1 && install_ghcup; 
    { ghcup install ghc --set "$GHC_VERSION" && check_ghc; } || die "Failed installing GHC"
    green "Installed GHC $GHC_VERSION"
}

check_cabal() {
    white "Checking for Cabal"
    if ! type cabal > /dev/null 2>&1; then 
        install_cabal  
    elif [ "$(cabal --version | head -n1 | awk '{print $3}')" != "$CABAL_VERSION" ]; then
        installed_cabal=$(cabal --version | head -n1 | awk '{print $3}')
        red "Currently cabal version $installed_cabal is installed, removing it and installing desired version $CABAL_VERSION"
        ghcup rm cabal "$installed_cabal"
        install_cabal
    else 
        green "$(cabal --version | head -n1)"
    fi 
}

install_cabal() {
    white "Installing cabal $CABAL_VERSION" 
    ! type ghcup >/dev/null 2>&1 && install_ghcup
    { ghcup install cabal --set "$CABAL_VERSION" && check_cabal; } || die "Failed installing cabal $CABAL_VERSION"
    green "Installed cabal $CABAL_VERSION"
    { white "Updating cabal" && cabal update; } || die "Updating cabal failed"
    export PATH="$HOME/.cabal/bin:$HOME/.ghcup/bin:$PATH"
    green "Updated cabal"
}

setup_workdir() {
    ({
    check_directory "working" "$WORK_DIR" &&
    check_directory "ipc" "$IPC_DIR" &&
    check_directory "config" "$CONFIG_DIR" &&
    check_directory "data" "$DATA_DIR" &&
    check_directory "testnet" "$TESTNET_DATA_DIR" &&
    check_directory "mainnet" "$MAINNET_DATA_DIR";
    } || die "Failed setting up $WORK_DIR")
    green "Successfully setup working directory"
}

install_libsodium() {
    check_repository "$LIBSODIUM_DIR" "$LIBSODIUM_URL" "libsodium"
    change_directory "$LIBSODIUM_DIR"
    white "Installing libsodium to $LIBSODIUM_DIR"
    ({ git checkout 66f017f1  >/dev/null 2>&1 &&
    ./autogen.sh >/dev/null 2>&1 &&
    ./configure >/dev/null 2>&1 &&
    make >/dev/null  2>&1 &&
    sudo make install >/dev/null 2>&1; 
    } || die "Failed installing libsodium")
    green "Successfully installed libsodium"
}

check_repository() {
    if [ -d "$1" ]; then
        white "$1 directory found, checking for git repository"
        if [ ! -d "$1/.git" ]; then 
            white "$1 direcory exists and is not a git repository, checking if its empty"
            if [ -z "$(ls -A "$1")" ]; then
                white "$1 is empty, cloning into it"
                clone_repository "$2" "$1" "$3"
            else 
                die "Can't clone repository, directory is not empty"
            fi
        else
            green "$3 repository found"
        fi
    else 
        white "$3 directory not found, cloning it into $1"
        clone_repository "$2" "$1" "$3"
    fi 
}

clone_repository() {
    white "Cloning $3 repository to $2"
    git clone "$1" "$2" >/dev/null 2>&1 || die "Failed cloning $3 repository to $2"
    green "Successfully cloned $3 repository to $2"
}

clone_repositories() {
    white "Downloading cardano repositories"
    change_directory "$WORK_DIR"
    check_repository "$CARDANO_NODE_DIR" "$CARDANO_NODE_URL" "cardano-node"
    check_repository "$CARDANO_DB_SYNC_DIR" "$CARDANO_DB_SYNC_URL" "cardano-db-sync"
}

checkout_latest_version() {
    white "Checking out latest node version"
    change_directory "$CARDANO_NODE_DIR"
    git checkout tags/"$LATEST_VERSION" >/dev/null 2>&1 || die "Failed checking out version $LATEST_VERSION"
    green "Successfully checked out latest node version $LATEST_VERSION"
}

configure_build() {
    white "Making sure correct build dependencies are available"
    { check_cabal && check_ghc; } || die "Failed making sure build dependencies are available"
    white "Updating cabal"
    cabal update >/dev/null 2>&1 && green "Updated cabal"
    white "Configuring the build options to build with GHC version $GHC_VERSION"
    cabal configure --with-compiler=ghc-"$GHC_VERSION" || die "Failed configuring the build options"
    green "Configured build options"
}

check_project_file() {
    white "Checking local project file"
    if [ -f "$PROJECT_FILE" ]; then 
        if grep -q "package cardano-crypto-praos" "$PROJECT_FILE" && grep -q "package cardano-crypto-praos" "$PROJECT_FILE"; then
            white "Skip adjustment of $PROJECT_FILE"
        else 
            update_project_file || die "Failed updating project file $PROJECT_FILE"
        fi
    else
        update_project_file || die "Failed updating project file $PROJECT_FILE"
    fi
}

update_project_file() {
    white "Update the local project file to use libsodium"
    echo "package cardano-crypto-praos" >> "$PROJECT_FILE" 
    echo "  flags: -external-libsodium-vrf" >> "$PROJECT_FILE"
    green "Updated local project file"
}

build_latest_node() {
    white "Start building latest cardano-node"
    clone_repositories
    checkout_latest_version
    configure_build
    check_project_file
    green "Building and installing the node to produce executables binaries, this might take a while..."
    cabal build all
}

copy_binary() {
    white "Copying $1 binary to $INSTALL_DIR"
    cp -p "$("$BIN_PATH" "$1")" "$INSTALL_DIR" || die "Failed copying $1 binary to $INSTALL_DIR"
    green "Successfully copied $1 binary to $INSTALL_DIR"
}

install_binaries() {
    check_directory "binary install" "$INSTALL_DIR"
    white "Installing the binaries to $INSTALL_DIR"
    copy_binary "cardano-node"
    copy_binary "cardano-cli"
    green "Successfully copied binaries to $INSTALL_DIR"
}

check_component() {
    white "Checking $1 installation"
    if ! [ -f "$2" ]; then 
        die "Failed installing $1"
    elif [ "$($1 --version | awk '{print $2}'| head -n1)" = "$LATEST_VERSION" ]; then
        $1 --version | head -n1 && green "Successfully installed $1 binary"
    else 
        die "Failed installing $1"
    fi
}

check_install() {
    white "Checking cardano component binary installatin"
    check_component "cardano-node" "$NODE_BINARY" 
    check_component "cardano-cli" "$CLI_BINARY" 
    green "Successfully installed cardano component binaries"
}

install_latest_node() {
    setup_packages
    prepare_build 
    build_latest_node 
    install_binaries 
    check_install
    succeed "Successfully installed latest cardano node! :)" 
}

main() {
    check_version
    check_root
    check_run_control
    install_latest_node
}

main