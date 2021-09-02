#!/bin/sh

RUNNER="${SUDO_USER:-$USER}"
USER_HOME="/home/$RUNNER"
WORK_DIR="$USER_HOME/.cardano"
CARDANO_NODE_DIR="$WORK_DIR/cardano-node"
CARDANO_DB_SYNC_DIR="$WORK_DIR/cardano-db-sync"
CARDANO_WALLET_DIR="$WORK_DIR/cardano-wallet"
BIN_PATH="$CARDANO_NODE_DIR/scripts/bin-path.sh"
PROJECT_FILE="$CARDANO_NODE_DIR/cabal.project.local"
WALLET_PROJECT_FILE="$CARDANO_WALLET_DIR/cabal.project.local"
INSTALL_DIR="$USER_HOME/.local/bin"
IPC_DIR="$WORK_DIR/ipc"
CONFIG_DIR="$WORK_DIR/config"
DATA_DIR="$WORK_DIR/data/db"
MAINNET_DATA_DIR="$DATA_DIR/mainnet"
TESTNET_DATA_DIR="$DATA_DIR/testnet"
LIBSODIUM_DIR="$WORK_DIR/libsodium"
GHCUP_INSTALL_PATH="$USER_HOME/.ghcup"
GHCUP_BINARY="$GHCUP_INSTALL_PATH/bin/ghcup"
GHC_BINARY="$GHCUP_INSTALL_PATH/bin/ghc"
CABAL_BINARY="$GHCUP_INSTALL_PATH/bin/cabal"
CLI_BINARY="$INSTALL_DIR/cardano-cli"
NODE_BINARY="$INSTALL_DIR/cardano-node"
WALLET_BINARY="$INSTALL_DIR/cardano-wallet"
GHC_VERSION="8.10.4"
CABAL_VERSION="3.4.0.0"
PLATFORM="$(uname -s)"
DISTRO="$(cat /etc/*ease | grep "DISTRIB_ID" | awk -F '=' '{print $2}')"
RELEASE_URL="https://api.github.com/repos/input-output-hk/cardano-node/releases/latest"
CARDANO_NODE_URL="https://github.com/input-output-hk/cardano-node.git"
CARDANO_DB_SYNC_URL="https://github.com/input-output-hk/cardano-db-sync.git"
CARDANO_WALLET_URL="https://github.com/input-output-hk/cardano-wallet.git"
WALLET_RELEASE_URL="https://api.github.com/repos/input-output-hk/cardano-wallet/releases/latest"
LIBSODIUM_URL="https://github.com/input-output-hk/libsodium"
GHCUP_INSTALL_URL="https://get-ghcup.haskell.org"
LATEST_VERSION="$(curl -s "$RELEASE_URL" | grep tag_name | awk -F ':' '{print $2}' | tr -d '"' | tr -d ',' | tr -d '[:space:]')"
LATEST_WALLET_VERSION="$(curl -s "$WALLET_RELEASE_URL" | grep tag_name | awk -F ':' '{print $2}' | tr -d '"' | tr -d ',' | tr -d '[:space:]')"
WALLET_VERSION_PRE_PROCESSED="$(echo "$LATEST_WALLET_VERSION" | tr -d 'v'| tr '-' '.')"
WALLET_YEAR="$(echo "$WALLET_VERSION_PRE_PROCESSED" | awk -F '.' '{print $1}')"
WALLET_MONTH="$(echo "$WALLET_VERSION_PRE_PROCESSED" | awk -F '.' '{print $2}'| tr -d '0')"
WALLET_DAYS="$(echo "$WALLET_VERSION_PRE_PROCESSED" | awk -F '.' '{print $3}')"
WALLET_VERSION="$WALLET_YEAR.$WALLET_MONTH.$WALLET_DAYS"
WALLET_BIN_PATH="$CARDANO_WALLET_DIR/dist-newstyle/build/x86_64-linux/ghc-$GHC_VERSION/cardano-wallet-$WALLET_VERSION/x/cardano-wallet/build/cardano-wallet/cardano-wallet"
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
YELLOW="\\033[0;33m"
RED="\\033[0;31m"
PURPLE="\\033[0;35m"
SET="\\033[0m\\n"

normal() {
    printf "%s\n" "$1"
}

white() {
    printf "$WHITE%s$SET" "$1"
}

green() {
    printf "$GREEN%s$SET" "$1"
}

yellow() {
    printf "$YELLOW%s$SET" "$1"
}

red() {
    printf "$RED%s$SET" "$1"
}

purple() {
    printf "$PURPLE%s$SET" "$1"
}

die() {
    red "$1" && exit 1
}

succeed() {
    green "$1" && exit 0
}

check_version() {
    [ -z "$LATEST_VERSION" ] && red "Couldn't fetch latest node version, try again after making sure you have curl installed" && exit 1
    if type "$NODE_BINARY" >/dev/null 2>&1; then 
        installed_cardano_node_version=$("$NODE_BINARY"  --version | awk '{print $2}'| head -n1)
        if [ "$installed_cardano_node_version" = "$LATEST_VERSION" ]; then 
            succeed "Already installed latest cardano-node (v$installed_cardano_node_version)"
        else 
            white "Updating cardano-node version $installed_cardano_node_version to version $LATEST_VERSION"
            install_latest_node || die "Failed updating node to $LATEST_VERSION"
        fi
    else 
        white "Installing the latest cardano-node ($LATEST_VERSION) and its components to $WORK_DIR"
    fi 
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then 
        white "This script will require root privileges to install the required packages"
        sudo echo >/dev/null 2>&1
        green "Obtained root privileges"
    fi
}

check_directory() {
    white "Checking for $1 directory in $2"
    { ! [ -d "$2" ] && create_directory "$1" "$2"; } || green "$2 directory found, skipped creating"
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
            SHELL_PROFILE_FILE="$USER_HOME/.zshrc"
            MY_SHELL="zsh" ;;
        */bash)
            SHELL_PROFILE_FILE="$USER_HOME/.bashrc"
            MY_SHELL="bash" ;;
        */sh) 
            if [ -n "$BASH" ]; then
                SHELL_PROFILE_FILE="$USER_HOME/.bashrc"
                MY_SHELL="bash"
            elif [ -n "$ZSH_VERSION" ]; then
                white "Found zsh"
                SHELL_PROFILE_FILE="$USER_HOME/.zshrc"
                MY_SHELL="zsh"
            fi ;;
        *) red "No shell detected exporting environment variables to current shell session only";;
    esac
}

ask_change_shell_run_control() {
    while true; do
        [ -z "$MY_SHELL" ] && return 0
        green "Detected $MY_SHELL"
        [ "$CONFIRM" ] && purple "Automatically adding path variables to $SHELL_PROFILE_FILE" && return 1
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

check_env() {
    white "Checking for $3 in $SHELL_PROFILE_FILE"
    if grep -q "$1" "$SHELL_PROFILE_FILE"; then 
        green "$3 is already set"
    else 
        echo "$2" >> "$SHELL_PROFILE_FILE"
        SOURCE_REQUIRED=true
        green "Set $3 in $SHELL_PROFILE_FILE"
    fi
}

change_shell_run_control() {
    case "$1" in
        1)
            check_env "LD_LIBRARY_PATH" "$LD_LIBRARY" "libsodium library path"
            check_env "PKG_CONFIG_PATH" "$PKG_CONFIG" "libsodium package configuration path"
            check_env "CARDANO_NODE_SOCKET_PATH" "$CARDANO_NODE_SOCKET" "socket for inter-process-communication"
            check_env "\.local/bin" "$INSTALL_PATH" "cardano binary installation path"
            check_env "\.ghcup/bin" "$GHCUP_PATH" "GHCup installation path";;
        *) 
            white "Exporting variables"
            export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
            export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"
            export CARDANO_NODE_SOCKET_PATH="$USER_HOME/cardano/ipc/node.socket"
            export PATH="$USER_HOME/.local/bin/:$PATH"
            export PATH="$USER_HOME/.cabal/bin:$USER_HOME/.ghcup/bin:$PATH" ;;
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
    white "Checking for GHCup"
    if [ -d "$GHCUP_INSTALL_PATH" ]; then 
        if [ -f "$GHCUP_BINARY" ]; then
            green "$("$GHCUP_BINARY" --version)"
        else 
            die "Failed installing GHCup"
        fi
    else 
        red "GHCup is not installed"
        install_ghcup;
    fi
}

install_ghcup() {
    if [ "$(id -u)" -eq 0 ]; then 
        {
        white "Installing GHCup as $RUNNER"
        ghcup_script="
        export BOOTSTRAP_HASKELL_NONINTERACTIVE=1  
        export BOOTSTRAP_HASKELL_GHC_VERSION=$GHC_VERSION
        export BOOTSTRAP_HASKELL_CABAL_VERSION=$CABAL_VERSION
        $(curl --proto '=https' --tlsv1.2 -sSf "$GHCUP_INSTALL_URL")"
        su - "$RUNNER" -c "eval $ghcup_script" >/dev/null 2>&1
        } || die "Failed installing GHCup"
    else 
        ({
        white "Installing GHCup"
        export BOOTSTRAP_HASKELL_NONINTERACTIVE=1
        export BOOTSTRAP_HASKELL_GHC_VERSION="$GHC_VERSION"
        export BOOTSTRAP_HASKELL_CABAL_VERSION="$CABAL_VERSION"
        curl --proto '=https' --tlsv1.2 -sSf "$GHCUP_INSTALL_URL" | sh >/dev/null 2>&1
        } || die "Failed installing GHCup")
    fi
    export PATH="$USER_HOME/.cabal/bin:$USER_HOME/.ghcup/bin:$PATH"
    green "Installed GHCup"
}

check_ghc() {
    white "Checking for GHC"
    if ! type "$GHC_BINARY" >/dev/null 2>&1; then 
        red "GHC is not installed"
        install_ghc
    elif [ "$("$GHC_BINARY" --version | awk '{print $8}')" != "$GHC_VERSION" ]; then
        export PATH="$USER_HOME/.cabal/bin:$USER_HOME/.ghcup/bin:$PATH"
        installed_ghc=$("$GHC_BINARY" --version | awk '{print $8}')
        red "Currently GHC $installed_ghc is installed, installing desired version $GHC_VERSION and setting it as default"
        install_ghc 
        white "$("$GHC_BINARY" --version)"
    else 
        green "$("$GHC_BINARY" --version)"
    fi 
}

install_ghc() {
    white "Installing GHC $GHC_VERSION"
    ! type "$GHCUP_BINARY" >/dev/null 2>&1 && install_ghcup; 
    {
    "$GHCUP_BINARY" install ghc "$GHC_VERSION" >/dev/null 2>&1 && 
    "$GHCUP_BINARY" set "$GHC_VERSION" >/dev/null 2>&1 &&
    export PATH="$USER_HOME/.cabal/bin:$USER_HOME/.ghcup/bin:$PATH" &&
    check_ghc
    } || die "Failed installing GHC"
    export PATH="$USER_HOME/.cabal/bin:$USER_HOME/.ghcup/bin:$PATH"
    green "Installed GHC $GHC_VERSION"
}

check_cabal() {
    white "Checking for Cabal"
    if ! type "$CABAL_BINARY" > /dev/null 2>&1; then 
        install_cabal  
    elif [ "$("$CABAL_BINARY" --version | head -n1 | awk '{print $3}')" != "$CABAL_VERSION" ]; then
        export PATH="$USER_HOME/.cabal/bin:$USER_HOME/.ghcup/bin:$PATH"
        installed_cabal=$(cabal --version | head -n1 | awk '{print $3}')
        red "Currently cabal version $installed_cabal is installed, installing desired version $CABAL_VERSION and setting it as default"
        install_cabal
    else 
        green "$("$CABAL_BINARY" --version | head -n1)"
    fi 
}

install_cabal() {
    white "Installing cabal $CABAL_VERSION" 
    ! type "$GHCUP_BINARY" >/dev/null 2>&1 && install_ghcup; 
    { 
    "$GHCUP_BINARY" install cabal "$CABAL_VERSION" >/dev/null 2>&1 &&
    "$GHCUP_BINARY" set cabal "$CABAL_VERSION" >/dev/null 2>&1 &&
    export PATH="$USER_HOME/.cabal/bin:$USER_HOME/.ghcup/bin:$PATH" &&
    check_cabal
    } || die "Failed installing cabal $CABAL_VERSION"
    green "Installed cabal $CABAL_VERSION"
    { white "Updating cabal" && cabal update >/dev/null 2>&1; } || die "Updating cabal failed"
    export PATH="$USER_HOME/.cabal/bin:$USER_HOME/.ghcup/bin:$PATH"
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

clone_repositories() {
    white "Downloading cardano repositories"
    change_directory "$WORK_DIR"
    check_repository "$CARDANO_NODE_DIR" "$CARDANO_NODE_URL" "cardano-node"
    check_repository "$CARDANO_DB_SYNC_DIR" "$CARDANO_DB_SYNC_URL" "cardano-db-sync"
    check_repository "$CARDANO_WALLET_DIR" "$CARDANO_WALLET_URL" "cardano-wallet"
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

checkout_latest_node_version() {
    white "Checking out latest node version"
    change_directory "$CARDANO_NODE_DIR"
    git fetch --all --recurse-submodules --tags
    git checkout tags/"$LATEST_VERSION" >/dev/null 2>&1 || die "Failed checking out version $LATEST_VERSION"
    green "Successfully checked out latest node version $LATEST_VERSION"
}

checkout_latest_wallet_version() {
    white "Checking out latest wallet version"
    change_directory "$CARDANO_WALLET_DIR"
    git checkout tags/"$LATEST_WALLET_VERSION" >/dev/null 2>&1 || die "Failed checking out wallet version $LATEST_WALLET_VERSION"
    green "Successfully checked out latest wallet version $LATEST_WALLET_VERSION"
}

configure_node_build() {
    white "Making sure correct node build dependencies are available"
    { check_cabal && check_ghc; } || die "Failed making sure node build dependencies are available"
    white "Updating cabal"
    "$CABAL_BINARY" update >/dev/null 2>&1 && green "Updated cabal"
    [ -f "$PROJECT_FILE" ] && rm -rf "$PROJECT_FILE"
    white "Configuring the node build options to build with GHC version $GHC_VERSION"
    export PATH="$USER_HOME/.cabal/bin:$USER_HOME/.ghcup/bin:$PATH"
    if [ "$VERBOSE" ]; then 
        "$CABAL_BINARY" configure --with-compiler=ghc-"$GHC_VERSION" || die "Failed configuring the node build options"
    else 
        "$CABAL_BINARY" configure --with-compiler=ghc-"$GHC_VERSION" >/dev/null 2>&1 || die "Failed configuring the node build options"
    fi    
    green "Configured node build options"
}

configure_wallet_build() {
    white "Making sure correct wallet build dependencies are available"
    { check_cabal && check_ghc; } || die "Failed making sure wallet build dependencies are available"
    white "Updating cabal"
    "$CABAL_BINARY" update >/dev/null 2>&1 && green "Updated cabal"
    [ -f "$WALLET_PROJECT_FILE" ] && rm -rf "$WALLET_PROJECT_FILE"
    white "Configuring the wallet build options to build with GHC version $GHC_VERSION"
    export PATH="$USER_HOME/.cabal/bin:$USER_HOME/.ghcup/bin:$PATH"
    if [ "$VERBOSE" ]; then 
        "$CABAL_BINARY" configure --with-compiler=ghc-"$GHC_VERSION" --constraint="random<1.2" || die "Failed configuring the wallet build options"
    else 
        "$CABAL_BINARY" configure --with-compiler=ghc-"$GHC_VERSION" --constraint="random<1.2" >/dev/null 2>&1 || die "Failed configuring the wallet build options"
    fi    
    green "Configured wallet build options"
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
    checkout_latest_node_version
    configure_node_build
    check_project_file
    green "Building and installing the node to produce executables binaries, this might take a while..."
    if [ "$VERBOSE" ]; then 
        cabal build all
    else 
        cabal build all >/dev/null 2>&1
    fi 
}

build_latest_wallet() {
    white "Start building latest cardano-wallet"
    checkout_latest_wallet_version
    configure_wallet_build
    green "Building and installing the the to produce an executable binary, this might take a while..."
    if [ "$VERBOSE" ]; then 
        cabal build all
    else 
        cabal build all >/dev/null 2>&1
    fi 
}

copy_binary() {
    white "Copying $1 binary to $INSTALL_DIR"
    cp -p "$("$BIN_PATH" "$1")" "$INSTALL_DIR" || die "Failed copying $1 binary to $INSTALL_DIR"
    green "Successfully copied $1 binary to $INSTALL_DIR"
}

copy_wallet_binary() {
    white "Copying wallet binary to $INSTALL_DIR"
    cp -p "$WALLET_BIN_PATH" "$INSTALL_DIR" || die "Failed copying wallet binary to $INSTALL_DIR"
    green "Successfully copied wallet binary to $INSTALL_DIR"
}

install_binaries() {
    check_directory "binary install" "$INSTALL_DIR"
    white "Installing the binaries to $INSTALL_DIR"
    change_directory "$CARDANO_NODE_DIR"
    copy_binary "cardano-node"
    copy_binary "cardano-cli"
    copy_wallet_binary
    green "Successfully copied binaries to $INSTALL_DIR"
}

check_component() {
    white "Checking $1 installation"
    if ! [ -f "$2" ]; then 
        die "Failed installing $1"
    elif [ "$($2 --version | awk '{print $2}'| head -n1)" = "$LATEST_VERSION" ]; then
        "$2" --version | head -n1 && green "Successfully installed $1 binary"
    else 
        die "Failed installing $1"
    fi
}

check_wallet_installation() {
    white "Checking cardano-wallet installation"
    if ! [ -f "$WALLET_BINARY" ]; then 
        die "Failed installing cardano-wallet"
    elif [ "$(cardano-wallet version | awk '{print $1}')" = "$LATEST_WALLET_VERSION" ]; then
        cardano-wallet version && green "Successfully installed cardano-wallet binary"
    else 
        die "Failed installing cardano-wallet"
    fi
}

check_install() {
    white "Checking cardano component binary installatin"
    check_component "cardano-node" "$NODE_BINARY" 
    check_component "cardano-cli" "$CLI_BINARY" 
    check_wallet_installation
    green "Successfully installed cardano component binaries"
}

check_ownerships() {
    if [ "$(id -u)" -eq 0 ]; then 
        set_ownership "$WORK_DIR"
        set_ownership "$NODE_BINARY"
        set_ownership "$CLI_BINARY"
        set_ownership "$WALLET_BINARY"
    fi
}

set_ownership() {
    chown -R "$RUNNER":"$RUNNER" "$1"
}

install_latest_node() {
    setup_packages
    prepare_build 
    clone_repositories
    build_latest_node 
    build_latest_wallet
    install_binaries 
    check_install
    check_ownerships
    check_required_sourcing
    succeed "Successfully installed latest cardano node! :)"
}

check_required_sourcing() {
    [ -z "$SOURCE_REQUIRED" ] && green "Source $SHELL_PROFILE_FILE or restart your terminal session to start using the binaries"
}

check_arguments() {
    while [ "$#" -gt 0 ]; do
    case $1 in
        -h|--help) help && exit 0 ;;
        -v|--version) version;;
        -y|--yes) confirm_prompts;;
        --verbose) verbose;;
        *) red "Unknown parameter passed: $1" && usage ;;
    esac
    shift
    done
}

confirm_prompts() {
    if [ -z "$CONFIRM" ]; then 
        CONFIRM=true
    else 
        die "Don't use optional flags multiple times"
    fi
}

verbose() {
    if [ -z "$VERBOSE" ]; then 
        yellow "Verbose mode selected"
        VERBOSE=true
    else 
        die "Don't use optional flags multiple times"
    fi
}

version() {
    normal "$LATEST_VERSION" && exit 0 
}

help() {
    normal "Usage:   setup.sh [ [ -y ] | [ -h | -v ] ] [ --verbose ]"
    normal 
    normal "This script installs the latest cardano node version"
    normal 
    normal "Available options"
    normal "  -y, --yes               Add environment variables to PATH automatically"
    normal "  -h, --help              Display this help message"
    normal "  -v, --version           Display the latest cardano node version"
    normal "  --verbose               Show output from configuring build options and compiling the node."
}

usage() {
    help && exit 1
}

main() {
    check_arguments "$@"
    check_version
    check_root
    check_run_control
    install_latest_node
}

main "$@"