#!/usr/bin/env sh

WORK_DIR="$HOME/cardano"

green() {
    printf "\\033[0;32m%s\\033[0m\\n" "$1"
}

red() {
    printf "\\033[0;31m%s\\033[0m\\n" "$1"
}

white() {
    printf "\033[1;37m%s\\033[0m\\n" "$1"
}

find_shell() {
	case $SHELL in
		*/zsh)
			SHELL_PROFILE_FILE="$HOME/.zshrc"
            MY_SHELL="zsh" ;;
		*/bash)
			SHELL_PROFILE_FILE="$HOME/.bashrc"
            MY_SHELL="bash" ;;
		*/sh) 
			if [ -n "${BASH}" ]; then
				SHELL_PROFILE_FILE="$HOME/.bashrc"
                MY_SHELL="bash"
			elif [ -n "${ZSH_VERSION}" ]; then
				SHELL_PROFILE_FILE="$HOME/.zshrc"
                MY_SHELL="zsh"
			fi ;;
		*) ;;
	esac
}

ask_rc() {
	while true; do
        white "Detected ${MY_SHELL}"
        white "Do you want to automatically add the required PATH variables to \"${SHELL_PROFILE_FILE}\"?"
        white "[y] Yes  [n] No  [?] Help"
        read -r rc_answer
		case $rc_answer in
			[Yy]* | "") green "Proceeding to add PATH variables for ${MY_SHELL}" && return 1;;
			[Nn]*) red "Skipped, installer might fail, but you know best" && return 0;;
			*)
				white "Possible choices are:"
				green "Y - Yes (default)"
				red "N - No, don't mess with my configuration"
				white "Please make your choice and press ENTER." ;;
		esac
	done
	unset rc_answer
}

check_for_path_variables() {
    if [ -f "$SHELL_PROFILE_FILE" ]; then
        ld=$(grep LD_LIBRARY_PATH "${SHELL_PROFILE_FILE}")
        pkg=$(grep PKG_CONFIG_PATH "${SHELL_PROFILE_FILE}")
        bin=$(grep .local/bin/ "${SHELL_PROFILE_FILE}")
        socket=$(grep CARDANO_NODE_SOCKET_PATH "${SHELL_PROFILE_FILE}")
        [ -z "${ld}" ] && echo 'export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"' >> "${SHELL_PROFILE_FILE}"
        [ -z "${pkg}" ] && echo 'export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"' >> "${SHELL_PROFILE_FILE}"
        [ -z "${bin}" ] && echo 'export PATH="$HOME/.local/bin/:$PATH"' >> "${SHELL_PROFILE_FILE}"
        [ -z "${socket}" ] && echo 'export CARDANO_NODE_SOCKET_PATH="$HOME/cardano/ipc/node.socket"' >> "${SHELL_PROFILE_FILE}"
    else
        export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
        export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"
        export PATH="$HOME/.local/bin/:$PATH"
        export CARDANO_NODE_SOCKET_PATH="$HOME/cardano/ipc/node.socket"
    fi
}

adjust_rc() {
    case $1 in
		1) check_for_path_variables ;;
		*) ;;
	esac
}

get_root_privileges() {
    if [ "$(id -u)" -ne 0 ]; then
        white "This script requires root privileges"
        sudo echo # > /dev/null
    fi
}

install_os_packages() {
    plat=$(uname -s)
    dist=$(cat /etc/*ease | grep "DISTRIB_ID" | awk -F '=' '{print $2}')
    white "Detected platform $plat and distro $dist"
    case "${plat}" in 
        "linux" | "Linux")
            case "${dist}" in 
                Fedora*|Hat*|CentOs*)
                    white "Updating and installing operating system dependencies"
                    yum update -y # > /dev/null 2>&1 
                    yum install curl git gcc gcc-c++ tmux gmp-devel make tar xz wget zlib-devel libtool autoconf -y #  > /dev/null 2>&1
                    yum install systemd-devel ncurses-devel ncurses-compat-libs -y > /dev/null 2>&1
                    ;;
                Ubuntu*|Debian*)
                    white "Updating and installing operating system dependencies"
                    apt-get update -y > /dev/null 2>&1
                    apt-get install curl automake build-essential pkg-config libffi-dev libgmp-dev libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev make g++ tmux git jq wget libncursesw5 libtool autoconf -y # > /dev/null;
                    ;;
                *) red "Unsupported operating system :(" && exit 1
            esac ;;
        *) red "Unsupported operating system :(" && exit 1 
    esac
}

install_nix() {
    red "Nix is not installed, proceeding to install Nix"
    if [ "$(id -u)" -eq 0 ]; then
        echo "build-users-group =" > /etc/nix/nix.conf
        mkdir -m 0755 /nix && chown root /nix
    fi
    curl -L https://nixos.org/nix/install > install-nix.sh
    chmod +x install-nix.sh
    yes | ./install-nix.sh 
    rm ./install-nix.sh
}

set_nix_iohk_build_cache() {
    green "Setting IOHK build cache"
    mkdir -p /etc/nix
    cat << EOF | tee /etc/nix/nix.conf
    substituters = https://cache.nixos.org https://hydra.iohk.io
    trusted-public-keys = iohk.cachix.org-1:DpRUyj7h7V830dp/i6Nti+NEO2/nhblbov/8MW7Rqoo= hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
EOF
}

check_nix() {
    white "Checking for nix"
    if ! type nix > /dev/null 2>&1; then 
        install_nix
        set_nix_iohk_build_cache
    fi
}

install_ghcup() {
    white "Installing GHC"
    (BOOTSTRAP_HASKELL_NONINTERACTIVE=1 \
    BOOTSTRAP_HASKELL_NO_UPGRADE=1 \
    BOOTSTRAP_HASKELL_CABAL_VERSION="3.4.0.0" \
    BOOTSTRAP_HASKELL_GHC_VERSION="8.10.4" \
    BOOTSTRAP_HASKELL_VERBOSE=1 \
    BOOTSTRAP_HASKELL_ADJUST_BASHRC=true \
    curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh )
    . $HOME/.ghcup/env
}

check_ghcup() {
    white "Checking for ghcup"
    if ! type ghcup > /dev/null 2>&1; then 
        install_ghcup
    fi
}

install_ghc() {
    white "Installing GHC 8.10.4"
    ghcup install ghc --set 8.10.4
}

check_ghc() {
    white "Checking for GHC"
    ghcversion="8.10.4"
    if ! type ghc > /dev/null 2>&1; then 
        install_ghc
    elif [ "$(ghc --version | awk '{print $8}')" != $ghcversion ]; then
        install_ghc
    fi 
}

check_cabal() {
    cabalversion="3.4.0.0"
    white "Checking for Cabal"
    if ! type cabal > /dev/null 2>&1; then 
        red "Cabal is not installed properly"
        install_cabal  
    elif [ "$(cabal --version | head -n1 | awk '{print $3}')" != $cabalversion ]; then
        install_cabal
    fi 
}

install_cabal() {
   white "Installing cabal 3.4.0.0" 
   ghcup install cabal --set 3.4.0.0
}

check_dependencies() {
    check_nix
    check_ghcup
    check_ghc
    check_cabal
}

create_workdir() {
    white "Creating working directory in ${WORK_DIR}"
    mkdir -p "${WORK_DIR}" 
    cd "${WORK_DIR}" || exit 
    green "Created working directory"
}

check_existing_workdir() {
    white "Checking for existing working directory in ${WORK_DIR}"
    if ! [ -d "${WORK_DIR}" ]; then
        create_workdir
    else
        green "${WORK_DIR} already exists, skipping"
    fi
}

download_libsodium() {
    white "Downloading libsodium to ${WORK_DIR}"
    git clone https://github.com/input-output-hk/libsodium # > /dev/null 2>&1
    green "Downloaded libsodium"
}

install_libsodium() {
    download_libsodium
    white "Installing libsodium to ${WORK_DIR}"
    cd libsodium || exit
    git checkout 66f017f1 > /dev/null 2>&1
    ./autogen.sh > /dev/null 2>&1
    ./configure > /dev/null 2>&1
    make > /dev/null 2>&1
    make install > /dev/null 2>&1 
    green "Installed libsodium"
}

check_for_libsodium() {
    white "Checking for existing libsodium"
    if ! [ -d "${WORK_DIR}/libsodium" ]; then
        install_libsodium
    else
        green "Skipping installation of libsodium"
    fi
}

download_cardano_node_repository() {
    if ! [ -d "${WORK_DIR}/cardano-node" ]; then
        white "Downloading cardano-node repository"
        git clone https://github.com/input-output-hk/cardano-node.git # > /dev/null 2>&1
        green "Downloaded cardano-node repository"
    else 
        green "cardano-node repository found, skip pulling"
    fi 
}

download_cardano_db_sync_repository() {
    if ! [ -d "${WORK_DIR}/cardano-db-sync" ]; then
        white "Downloading cardano-db-sync repository"
        git clone https://github.com/input-output-hk/cardano-db-sync.git # > /dev/null 2>&1
        green "Downloaded cardano-db-sync repository"
    else
        green "cardano-db-sync repository found, skip pulling"
    fi 
}

create_folders() {
    if ! [ -d "${WORK_DIR}/data/db" ]; then 
        white "Adding db folder to working directory"
        mkdir -p "${WORK_DIR}"/data/db/mainnet
        mkdir -p "${WORK_DIR}"/data/db/testnet
        green "Created mainnet and testnet folders in ${WORK_DIR}/data/db/ folder"
    else 
        green "data/db folder found, skip creating"
    fi
    if ! [ -d "${WORK_DIR}/ipc" ]; then 
        white "Adding ipc folder"
        mkdir -p "${WORK_DIR}/ipc"
    else
        green "ipc folder found, skip creating"
    fi
}

download_cardano_repositories_to_workdir() {
    cd "${WORK_DIR}" || exit 
    download_cardano_node_repository
    download_cardano_db_sync_repository
    create_folders
}

checkout_latest_node_version() {
    cd "${WORK_DIR}"/cardano-node || exit
    white "Fetching latest node version"
    latest_node_version=$(curl -s https://api.github.com/repos/input-output-hk/cardano-node/releases/latest | grep tag_name | awk -F ':' '{print $2}' | tr -d '"' | tr -d ',' > /dev/null 2>&1) 
    white "$latest_node_version"
    if [ -z "$latest_node_version" ]; then
        git checkout tags/1.27.0
    else
        git checkout tags/"${latest_node_version}" # > /dev/null 2>&1
    fi
    green "Successfully checked out latest node version ${latest_node_version}"
}

configure_build_options() {
    white "Configuring the build options to build with GHC version 8.10.4"
    cabal configure --with-compiler=ghc-8.10.4 # > /dev/null 2>&1
    green "Configured build options"
}

update_local_project_file_to_use_libsodium_compiler() {
    #TODO: Check for existing project file with this content
    white "Update the local project file to use libsodium"
    echo "package cardano-crypto-praos" >>  cabal.project.local
    echo "  flags: -external-libsodium-vrf" >>  cabal.project.local
    green "Updated local project file"
}

build_latest_node_version() {
    check_for_libsodium
    download_cardano_repositories_to_workdir
    checkout_latest_node_version
    configure_build_options
    update_local_project_file_to_use_libsodium_compiler
    green "Building and installing the node to produce executables binaries, this might take a while..."
    cabal build all # > /dev/null 2>&1
}

check_for_binary_install_directory() {
    #TODO: Create variable for that, no hardcoding
    if ! [ -d "$HOME"/.local/bin ]; then 
        mkdir -p "$HOME"/.local/bin
    fi
}

installing_binaries_to_local_bin() {
    #TODO: Use variable here
    white "Installing the binaries to $HOME/.local/bin"
    check_for_binary_install_directory
    cp -p "$(./scripts/bin-path.sh cardano-node)" "$HOME"/.local/bin/
    cp -p "$(./scripts/bin-path.sh cardano-cli)" "$HOME"/.local/bin/
}

check_cardano_cli_installation() {
    cliversion="1.28.0"
    #TODO: Use variable here
    white "Checking cardano-cli installation"
    if ! [ -f "$HOME/.local/bin/cardano-cli" ]; then 
        red "Failed installing cardano-cli"
        exit 1
    elif [ "$(cardano-cli --version | awk '{print $2}'|head -n1)" != $cliversion ]; then
        green "Successfully installed cardano-cli"
    else 
        red "Failed installing cardano-cli"
    fi
}

check_cardano_node_installation() {
    nodeversion="1.28.0"
    #TODO: Use variable here
    white "Checking cardano-node installation"
    if ! [ -f "$HOME/.local/bin/cardano-node" ]; then 
        red "Failed installing cardano-node"
        exit 1
    elif [ "$(cardano-node --version | awk '{print $2}'|head -n1)" != $nodeversion ]; then
        green "Successfully installed cardano-node"
    else 
        red "Failed installing cardano-node"
    fi
}

check_installation() {
    white "Checking binaries"
    check_cardano_cli_installation
    check_cardano_node_installation
}

main() {
    white "Installing the latest cardano-node and its components to $HOME/cardano"
    get_root_privileges
    find_shell
    ask_rc
    ask_rc_answer=$?
    adjust_rc $ask_rc_answer
    install_os_packages
    check_dependencies
    check_existing_workdir
    build_latest_node_version
    installing_binaries_to_local_bin
    check_installation
    green "Source your shell to use the installed binaries"
}

main
