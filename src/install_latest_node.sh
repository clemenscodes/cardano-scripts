#!/usr/bin/env sh

WORK_DIR="${HOME}/cardano"
CARDANO_NODE_DIR="${WORK_DIR}/cardano-node"
CARDANO_DB_SYNC_DIR="${WORK_DIR}/cardano-db-sync"
PROJECT_FILE="${CARDANO_NODE_DIR}/cabal.project.local"
INSTALL_DIR="${HOME}/.local/bin"
IPC_DIR="${WORK_DIR}/ipc"
DATA_DIR="${WORK_DIR}/data/db"
CONFIG_DIR="${WORK_DIR}/config"
LIBSODIUM_DIR="${WORK_DIR}/libsodium"
CLI_BINARY="${INSTALL_DIR}/cardano-cli"
NODE_BINARY="${INSTALL_DIR}/cardano-node"
GHC_VERSION="8.10.4"
CABAL_VERSION="3.4.0.0"
PLATFORM=$(uname -s)
DISTRO=$(cat /etc/*ease | grep "DISTRIB_ID" | awk -F '=' '{print $2}')
RELEASE_URL="https://api.github.com/repos/input-output-hk/cardano-node/releases/latest"
LATEST_VERSION=$(curl -s "${RELEASE_URL}" | grep tag_name | awk -F ':' '{print $2}' | tr -d '"' | tr -d ',' | tr -d '[:space:]') 

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
        white "No shell found, exporting environment variables to current shell session only"
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

install_os_packages() {
        white "Detected platform ${PLATFORM} and distro ${DISTRO}"
    case "${PLATFORM}" in 
        "linux" | "Linux")
            case "${DISTRO}" in 
                Fedora*|Hat*|CentOs*)
                    white "Updating and installing operating system dependencies"
                    yum update -y > /dev/null 2>&1 
                    yum install curl git gcc gcc-c++ tmux gmp-devel make tar xz wget zlib-devel libtool autoconf -y  > /dev/null 2>&1
                    yum install systemd-devel ncurses-devel ncurses-compat-libs -y > /dev/null 2>&1
                    ;;
                Ubuntu*|Debian*)
                    white "Updating and installing operating system dependencies"
                    apt-get update -y > /dev/null 2>&1
                    apt-get install curl automake build-essential pkg-config libffi-dev libgmp-dev libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev make g++ tmux git jq wget libncursesw5 libtool autoconf -y > /dev/null 2>&1;
                    ;;
                *) red "Unsupported operating system :(" && exit 1
            esac ;;
        *) red "Unsupported operating system :(" && exit 1 
    esac
}

install_ghcup() {
    white "Installing ghcup"
    (
    export BOOTSTRAP_HASKELL_NONINTERACTIVE=1
    export BOOTSTRAP_HASKELL_NO_UPGRADE=1
    export BOOTSTRAP_HASKELL_VERBOSE=1
    export BOOTSTRAP_HASKELL_GHC_VERSION="${GHC_VERSION}"
    export BOOTSTRAP_HASKELL_CABAL_VERSION="${CABAL_VERSION}"
    export BOOTSTRAP_HASKELL_INSTALL_STACK=0 
    export BOOTSTRAP_HASKELL_INSTALL_HLS=0 
    export BOOTSTRAP_HASKELL_ADJUST_BASHRC=true
    curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
    )
}

check_ghcup() {
    white "Checking for ghcup"
    if ! type ghcup > /dev/null 2>&1; then 
        install_ghcup
    fi
    ghcup --version
}

install_ghc() {
    white "Installing GHC ${GHC_VERSION}"
    ghcup install ghc --set "${GHC_VERSION}"
}

check_ghc() {
    white "Checking for GHC"
    if ! type ghc > /dev/null 2>&1; then 
        install_ghc
    elif [ "$(ghc --version | awk '{print $8}')" != "${GHC_VERSION}" ]; then
        install_ghc
    fi 
    ghc --version
}

check_cabal() {
    white "Checking for Cabal"
    if ! type cabal > /dev/null 2>&1; then 
        red "Cabal is not installed properly"
        install_cabal  
    elif [ "$(cabal --version | head -n1 | awk '{print $3}')" != "${CABAL_VERSION}" ]; then
        install_cabal
    fi 
    cabal --version
    cabal update
}

install_cabal() {
   white "Installing cabal ${CABAL_VERSION}" 
   ghcup install cabal --set "${CABAL_VERSION}"
}

check_dependencies() {
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
    white "Downloading libsodium to ${LIBSODIUM_DIR}"
    git clone https://github.com/input-output-hk/libsodium # > /dev/null 2>&1
    green "Downloaded libsodium"
}

install_libsodium() {
    download_libsodium
    white "Installing libsodium to ${LIBSODIUM_DIR}"
    cd "${LIBSODIUM_DIR}" || exit
    git checkout 66f017f1 > /dev/null 2>&1
    ./autogen.sh > /dev/null 2>&1
    ./configure > /dev/null 2>&1
    make > /dev/null 2>&1
    make install > /dev/null 2>&1 
    green "Installed libsodium"
}

check_for_libsodium() {
    white "Checking for existing libsodium"
    if ! [ -d "${LIBSODIUM_DIR}" ]; then
        install_libsodium
    else
        green "Skipping installation of libsodium"
    fi
}

download_cardano_node_repository() {
    if ! [ -d "${CARDANO_NODE_DIR}" ]; then
        white "Downloading cardano-node repository"
        git clone https://github.com/input-output-hk/cardano-node.git # > /dev/null 2>&1
        green "Downloaded cardano-node repository"
    else 
        green "cardano-node repository found, skip pulling"
    fi 
}

download_cardano_db_sync_repository() {
    if ! [ -d "${CARDANO_DB_SYNC_DIR}" ]; then
        white "Downloading cardano-db-sync repository"
        git clone https://github.com/input-output-hk/cardano-db-sync.git # > /dev/null 2>&1
        green "Downloaded cardano-db-sync repository"
    else
        green "cardano-db-sync repository found, skip pulling"
    fi 
}

create_folders() {
    if ! [ -d "${DATA_DIR}" ]; then 
        white "Adding db folder to working directory"
        mkdir -p "${DATA_DIR}/mainnet"
        mkdir -p "${DATA_DIR}/testnet"
        green "Created mainnet and testnet folders in ${DATA_DIR} folder"
    else 
        green "${DATA_DIR} found, skip creating"
    fi
    if ! [ -d "${IPC_DIR}" ]; then 
        white "Adding ipc folder"
        mkdir -p "${IPC_DIR}"
    else
        green "ipc folder found, skip creating"
    fi
    if ! [ -d "${CONFIG_DIR}" ]; then 
        white "Adding config folder"
        mkdir -p "${CONFIG_DIR}"
    else
        green "config folder found, skip creating"
    fi

}

download_cardano_repositories_to_workdir() {
    cd "${WORK_DIR}" || exit 
    download_cardano_node_repository
    download_cardano_db_sync_repository
    create_folders
}

checkout_latest_node_version() {
    cd "${CARDANO_NODE_DIR}" || exit
    if [ -z "${LATEST_VERSION}" ]; then
        git checkout tags/1.27.0
    else
        git checkout tags/"${LATEST_VERSION}" # > /dev/null 2>&1
    fi
    green "Successfully checked out latest node version ${LATEST_VERSION}"
}

configure_build_options() {
    white "Configuring the build options to build with GHC version ${GHC_VERSION}"
    [ -f "${PROJECT_FILE}" ] && rm "${PROJECT_FILE}"
    cabal configure --with-compiler=ghc-"${GHC_VERSION}" # > /dev/null 2>&1
    green "Configured build options"
}

update_local_project_file_to_use_libsodium_compiler() {
    white "Update the local project file to use libsodium"
    echo "package cardano-crypto-praos" >> "${PROJECT_FILE}"
    echo "  flags: -external-libsodium-vrf" >> "${PROJECT_FILE}"
    green "Updated local project file"
}

check_local_project_file() {
    if ! [ -f "${PROJECT_FILE}" ]; then
        update_local_project_file_to_use_libsodium_compiler
    elif grep -q "package cardano-crypto-praos" "${PROJECT_FILE}" && grep -q "package cardano-crypto-praos" "${PROJECT_FILE}"; then
        white "Skip adjustment of ${PROJECT_FILE}"
    else 
        update_local_project_file_to_use_libsodium_compiler
    fi
}

build_latest_node_version() {
    check_for_libsodium
    download_cardano_repositories_to_workdir
    checkout_latest_node_version
    configure_build_options
    check_local_project_file
    green "Building and installing the node to produce executables binaries, this might take a while..."
    cabal build all # > /dev/null 2>&1
}

check_for_binary_install_directory() {
    if ! [ -d "${INSTALL_DIR}" ]; then 
        mkdir -p "${INSTALL_DIR}" 
    fi
}

installing_binaries_to_local_bin() {
    white "Installing the binaries to ${INSTALL_DIR}"
    check_for_binary_install_directory
    cp -p "$(./scripts/bin-path.sh cardano-node)" "${INSTALL_DIR}"
    cp -p "$(./scripts/bin-path.sh cardano-cli)" "${INSTALL_DIR}"
}

check_cardano_cli_installation() {
    white "Checking cardano-cli installation"
    if ! [ -f "${CLI_BINARY}" ]; then 
        red "Failed installing cardano-cli"
        exit 1
    elif [ "$("${CLI_BINARY}" --version | awk '{print $2}' | head -n1)" = "${LATEST_VERSION}" ]; then
        cardano-cli --version
        green "Successfully installed cardano-cli"
    else 
        red "Failed installing cardano-cli"
    fi
}

check_cardano_node_installation() {
    white "Checking cardano-node installation"
    if ! [ -f "${NODE_BINARY}" ]; then 
        red "Failed installing cardano-node"
        exit 1
    elif [ "$("{NODE_BINARY}" --version | awk '{print $2}'| head -n1)" = "${LATEST_VERSION}" ]; then
        cardano-node --version
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
    [ -z "${LATEST_VERSION}" ] && red "Couldn't fetch latest node version, exiting." && exit 1
    white "Installing the latest cardano-node (${LATEST_VERSION}) and its components to ${WORK_DIR}"
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
