#!/bin/sh

WORK_DIR="${HOME}/.cardano"
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
PLATFORM="$(uname -s)"
DISTRO="$(cat /etc/*ease | grep "DISTRIB_ID" | awk -F '=' '{print $2}')"
RELEASE_URL="https://api.github.com/repos/input-output-hk/cardano-node/releases/latest"
CARDANO_NODE_URL="https://github.com/input-output-hk/cardano-node.git"
CARDANO_DB_SYNC_URL="https://github.com/input-output-hk/cardano-db-sync.git"
LIBSODIUM_URL="https://github.com/input-output-hk/libsodium"
LATEST_VERSION="$(curl -s "${RELEASE_URL}" | grep tag_name | awk -F ':' '{print $2}' | tr -d '"' | tr -d ',' | tr -d '[:space:]')"
ENVIRONMENT="$(cat <<EOF
export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"             
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"
export PATH="$HOME/.local/bin/:$PATH"
export CARDANO_NODE_SOCKET_PATH="$HOME/.cardano/ipc/node.socket"
export PATH="$HOME/.cabal/bin:$HOME/.ghcup/bin:$PATH"
EOF
)"

white() {
    printf "\033[1;37m%s\\033[0m\\n" "$1"
}

green() {
    printf "\\033[0;32m%s\\033[0m\\n" "$1"
}

red() {
    printf "\\033[0;31m%s\\033[0m\\n" "$1"
}

die() {
    (>&2 printf "\\033[0;31m%s\\033[0m\\n" "$1")
    exit 1
}

succeed() {
    printf "\\033[0;32m%s\\033[0m\\n" "$1"
    exit 0
}

check_version() {
    if type cardano-node >/dev/null 2>&1; then 
        installed_cardano_node_version=$(cardano-node  --version | awk '{print $2}'| head -n1)
        if [ "${installed_cardano_node_version}" = "${LATEST_VERSION}" ]; then 
            succeed "Already installed latest cardano-node (v${installed_cardano_node_version})"
        else 
            white "Updating cardano-node version ${installed_cardano_node_version} to version ${LATEST_VERSION}"
            install_latest_node || die "Failed updating node to ${LATEST_VERSION}"
       fi
    fi 
}

find_shell() {
    case $SHELL in
        */zsh)
            white "Found zsh"
            SHELL_PROFILE_FILE="$HOME/.zshrc"
            MY_SHELL="zsh" ;;
        */bash)
            white "Found bash"
            SHELL_PROFILE_FILE="$HOME/.bashrc"
            MY_SHELL="bash" ;;
        */sh) 
            white "Found sh"
            if [ -n "${BASH}" ]; then
                white "Found bash"
                SHELL_PROFILE_FILE="$HOME/.bashrc"
                MY_SHELL="bash"
            elif [ -n "${ZSH_VERSION}" ]; then
                white "Found zsh"
                SHELL_PROFILE_FILE="$HOME/.zshrc"
                MY_SHELL="zsh"
            fi ;;
        *) red "No shell found, exporting environment variables to current shell session only" ;;
    esac
}

ask_rc() {
    while true; do
        [ -z "${MY_SHELL}" ] && return 0
        white "Detected ${MY_SHELL}"
        white "Do you want to automatically add the required PATH variables to \"${SHELL_PROFILE_FILE}\"?"
        white "[y] Yes (default) [n] No  [?] Help"
        read -r rc_answer
        case $rc_answer in
            [Yy]* | "") green "Proceeding to add PATH variables for ${MY_SHELL}" && return 1;;
            [Nn]*) red "Skipped adding PATH variables" && return 0;;
            *)
                white "Possible choices are:"
                green "Y - Yes (default)"
                red "N - No, don't mess with my configuration"
                white "Please make your choice and press ENTER." ;;
        esac
    done
    unset rc_answer
}

adjust_rc() {
    case $1 in
        1) echo "${ENVIRONMENT}" >> "${SHELL_PROFILE_FILE}" ;;
        *) 
            white "Exporting variables"
            export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
            export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"
            export PATH="$HOME/.local/bin/:$PATH"
            export CARDANO_NODE_SOCKET_PATH="$HOME/cardano/ipc/node.socket"
            export PATH="$HOME/.cabal/bin:$HOME/.ghcup/bin:$PATH" ;;
    esac
}

install_os_packages() {
    { [ -z "${PLATFORM}" ] && red "Could not detect platform"; } || green "Detected ${PLATFORM}"
    { [ -z "${DISTRO}" ] && red "Could not detect distribution"; } || green "Detected ${DISTRO}"
    case "${PLATFORM}" in 
        "linux" | "Linux")
            case "${DISTRO}" in 
                Fedora*|Hat*|CentOs*)
                    { white "Updating"
                    sudo yum update -y >/dev/null 2>&1 &&
                    white "Installing curl git gcc gcc-c++ tmux gmp-devel make tar xz wget zlib-devel libtool autoconf" &&
                    sudo yum install curl git gcc gcc-c++ tmux gmp-devel make tar xz wget zlib-devel libtool autoconf -y >/dev/null 2>&1 &&
                    white "Installing systemd-devel ncurses-devel ncurses-compat-libs" &&
                    sudo yum install systemd-devel ncurses-devel ncurses-compat-libs -y >/dev/null 2>&1; } || die "Failed installing packages" 
                    ;;
                Ubuntu*|Debian*)
                    { white "Updating" &&
                    sudo apt-get update -y >/dev/null 2>&1 &&
                    white "Installing: curl automake build-essential pkg-config libffi-dev libgmp-dev libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev make g++ tmux git jq wget libncursesw5 libtool autoconf" &&
                    sudo apt-get install curl automake build-essential pkg-config libffi-dev libgmp-dev libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev make g++ tmux git jq wget libncursesw5 libtool autoconf -y >/dev/null 2>&1; } || die "Installation of packages failed"
                    ;;
                *) die "Unsupported distribution" 
            esac ;;
        *) die "Unsupported platform"
    esac
}

install_ghcup() {
    ({ white "Installing ghcup" &&
    export BOOTSTRAP_HASKELL_NONINTERACTIVE=1 &&
    export BOOTSTRAP_HASKELL_NO_UPGRADE=1 &&
    export BOOTSTRAP_HASKELL_VERBOSE=1 &&
    export BOOTSTRAP_HASKELL_GHC_VERSION="${GHC_VERSION}" &&
    export BOOTSTRAP_HASKELL_CABAL_VERSION="${CABAL_VERSION}" &&
    export BOOTSTRAP_HASKELL_ADJUST_BASHRC=true &&
    curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh; } || die "Failed installing ghcup")
}

check_ghcup() {
    white "Checking for ghcup"
    { ! type ghcup > /dev/null 2>&1 && install_ghcup; } || white "$(ghcup --version)"
}

install_ghc() {
    white "Installing GHC ${GHC_VERSION}"
    ! type ghcup >/dev/null 2>&1 && install_ghcup; 
    { ghcup install ghc --set "${GHC_VERSION}" && check_ghc; } || die "Failed installing GHC"
    green "Installed GHC ${GHC_VERSION}"
}

check_ghc() {
    white "Checking for GHC"
    if ! type ghc > /dev/null 2>&1; then 
        install_ghc
    elif [ "$(ghc --version | awk '{print $8}')" != "${GHC_VERSION}" ]; then
        export PATH="$HOME/.cabal/bin:$HOME/.ghcup/bin:$PATH"
        installed_ghc=$(ghc --version | awk '{print $8}')
        white "Currently GHC ${installed_ghc} is installed, removing it and installing desired version ${GHC_VERSION}"
        ghcup rm ghc "${installed_ghc}"
        install_ghc
    else 
        white "$(ghc --version)"
    fi 
}

check_cabal() {
    white "Checking for Cabal"
    if ! type cabal > /dev/null 2>&1; then 
        install_cabal  
    elif [ "$(cabal --version | head -n1 | awk '{print $3}')" != "${CABAL_VERSION}" ]; then
        installed_cabal=$(cabal --version | head -n1 | awk '{print $3}')
        white "Currently cabal version ${installed_cabal} is installed, removing it and installing desired version ${CABAL_VERSION}"
        ghcup rm cabal "${installed_cabal}"
        install_cabal
    else 
        white "$(cabal --version)"
    fi 
}

install_cabal() {
    white "Installing cabal ${CABAL_VERSION}" 
    ! type ghcup >/dev/null 2>&1 && install_ghcup
    { ghcup install cabal --set "${CABAL_VERSION}" && check_cabal; } || die "Failed installing cabal ${CABAL_VERSION}"
    green "Installed cabal ${CABAL_VERSION}"
    { white "Updating cabal" && cabal update; } || die "Updating cabal failed"
    green "Updated cabal"
}

check_dependencies() {
    white "Checking dependencies"
    { check_ghcup && check_ghc && check_cabal; } || die "Failed setting up dependencies"
}

create_workdir() {
    white "Creating working directory in ${WORK_DIR}" 
    mkdir -p "${WORK_DIR}" || die "Failed creating directory ${WORK_DIR}"
    cd "${WORK_DIR}" || die "Failed changing directory to ${WORK_DIR}"
    { check_data_dir && check_ipc_dir && check_config_dir; } || die "Failed setting up ${WORK_DIR}" 
    green "Created working directory"
}

check_data_dir() {
    white "Checking data directory in working directory"
    if ! [ -d "${DATA_DIR}" ]; then 
        white "Adding db folder to working directory"
        { mkdir -p "${DATA_DIR}/mainnet" && mkdir -p "${DATA_DIR}/testnet"; } || die "Failed creating directories in ${DATA_DIR}"
        green "Created mainnet and testnet folders in ${DATA_DIR} folder"
    else 
        green "${DATA_DIR} found, skipped creating"
    fi
}

check_ipc_dir() {
    white "Checking ipc directory in working directory"
    { ! [ -d "${IPC_DIR}" ] && white "Adding ipc folder" && mkdir -p "${IPC_DIR}"; } || green "ipc folder found, skipped creating"
}

check_config_dir() {
    white "Checking config directory in working directory"
    { ! [ -d "${CONFIG_DIR}" ] && white "Adding config folder" && mkdir -p "${CONFIG_DIR}"; } || green "config folder found, skipped creating"
}

check_workdir() {
    white "Checking for existing working directory in ${WORK_DIR}"
    { ! [ -d "${WORK_DIR}" ] && create_workdir; } || green "${WORK_DIR} already exists, skipping"
    { check_data_dir && check_ipc_dir && check_config_dir; } || die "Failed setting up ${WORK_DIR}" 
}

download_libsodium() {
    white "Downloading libsodium to ${LIBSODIUM_DIR}"
    git clone "${LIBSODIUM_URL}" >/dev/null 2>&1 || die "Failed downloading libsodium"
    green "Downloaded libsodium"
}

install_libsodium() {
    download_libsodium
    white "Installing libsodium to ${LIBSODIUM_DIR}"
    cd "${LIBSODIUM_DIR}" || die "Failed changing directory to ${LIBSODIUM_DIR}" 
    { git checkout 66f017f1  >/dev/null 2>&1 &&
    ./autogen.sh >/dev/null 2>&1 &&
    ./configure >/dev/null 2>&1 &&
    make  >/dev/null  2>&1 &&
    sudo make install >/dev/null 2>&1; } || die "Failed installing libsodium"
    green "Installed libsodium"
}

check_for_libsodium() {
    white "Checking for existing libsodium"
    { ! [ -d "${LIBSODIUM_DIR}" ] && install_libsodium; } || green "Skipping installation of libsodium"
}

download_cardano_node() {
    if ! [ -d "${CARDANO_NODE_DIR}" ]; then
        white "Downloading cardano-node repository"
        git clone "${CARDANO_NODE_URL}" >/dev/null 2>&1 || die "Failed downloading cardano-node repository"
        green "Downloaded cardano-node repository" 
    else 
        green "cardano-node repository found, skip pulling"
    fi 
}

download_cardano_db_sync() {
    if ! [ -d "${CARDANO_DB_SYNC_DIR}" ]; then
        white "Downloading cardano-db-sync repository"
        git clone "${CARDANO_DB_SYNC_URL}" >/dev/null 2>&1 || die "Failed downloading cardano-db-sync repository"
        green "Downloaded cardano-db-sync repository"
    else
        green "cardano-db-sync repository found, skip pulling"
    fi 
}

download_cardano_repositories() {
    white "Downloading cardano repositories"
    cd "${WORK_DIR}" || die "Failed changing directory to ${WORK_DIR}" 
    { download_cardano_node && download_cardano_db_sync; } || die "Failed downloading cardano repositories"
}

checkout_latest_node_version() {
    white "Checking out latest node version"
    cd "${CARDANO_NODE_DIR}" || die "Failed changing directory to ${CARDANO_NODE_DIR}" 
    [ -z "${LATEST_VERSION}" ] && die "Couldn't fetch latest node version, try again after making sure you have curl installed"
    git checkout tags/"${LATEST_VERSION}" >/dev/null 2>&1 || die "Failed checking out version ${LATEST_VERSION}"
    green "Successfully checked out latest node version ${LATEST_VERSION}"
}

configure_build_options() {
    white "Configuring the build options to build with GHC version ${GHC_VERSION}"
    [ -f "${PROJECT_FILE}" ] && rm "${PROJECT_FILE}"
    white "Checking Cabal and GHC to again to really make sure they are installed"
    { check_cabal && check_ghc; } || die "Failed making sure the build dependencies are installed"
    cabal configure --with-compiler=ghc-"${GHC_VERSION}" >/dev/null 2>&1 || die "Failed configuring the build options"
    green "Configured build options"
}

update_local_project_file_to_use_libsodium_compiler() {
    white "Update the local project file to use libsodium"
    echo "package cardano-crypto-praos" >> "${PROJECT_FILE}" 
    echo "  flags: -external-libsodium-vrf" >> "${PROJECT_FILE}"
    green "Updated local project file"
}

check_local_project_file() {
    white "Checking local project file"
    if ! [ -f "${PROJECT_FILE}" ]; then
        update_local_project_file_to_use_libsodium_compiler
    elif grep -q "package cardano-crypto-praos" "${PROJECT_FILE}" && grep -q "package cardano-crypto-praos" "${PROJECT_FILE}"; then
        white "Skip adjustment of ${PROJECT_FILE}"
    else 
        update_local_project_file_to_use_libsodium_compiler
    fi
}

prepare_build() {
    white "Preparing build"
    { check_dependencies && check_workdir && check_for_libsodium; } || die "Failed preparing build"
    green "Prepared build"
}

build_latest_node_version() {
    white "Start building latest cardano-node"
    { download_cardano_repositories &&
    checkout_latest_node_version &&
    configure_build_options &&
    check_local_project_file &&
    green "Building and installing the node to produce executables binaries, this might take a while..." &&
    cabal build all; } || red "Failed building latest cardano node"
}

check_install_dir() {
    white "Checking for binary install directory ${INSTALL_DIR}"
    { ! [ -d "${INSTALL_DIR}" ] && mkdir -p "${INSTALL_DIR}" && green "Created install directory ${INSTALL_DIR}"; } ||
        die "Failed creating install directory ${INSTALL_DIR}"

}

install_binaries() {
    check_install_dir
    white "Installing the binaries to ${INSTALL_DIR}"
    { cp -p "$(./scripts/bin-path.sh cardano-node)" "${INSTALL_DIR}" && cp -p "$(./scripts/bin-path.sh cardano-cli)" "${INSTALL_DIR}"; } ||
        die "Failed installing binaries to ${INSTALL_DIR}"
}

check_cardano_cli_install() {
    white "Checking cardano-cli installation"
    if ! [ -f "${CLI_BINARY}" ]; then 
        die "Failed installing cardano-cli"
    elif [ "$("${CLI_BINARY}" --version | awk '{print $2}' | head -n1)" = "${LATEST_VERSION}" ]; then
        cardano-cli --version && green "Successfully installed cardano-cli binary"
    else 
        die "Failed installing cardano-cli"
    fi
}

check_cardano_node_install() {
    white "Checking cardano-node installation"
    if ! [ -f "${NODE_BINARY}" ]; then 
        die "Failed installing cardano-node"
    elif [ "$("${NODE_BINARY}" --version | awk '{print $2}'| head -n1)" = "${LATEST_VERSION}" ]; then
        cardano-node --version && green "Successfully installed cardano-node binary"
    else 
        die "Failed installing cardano-node"
    fi
}

install_latest_node() {
    { prepare_build && build_latest_node_version && install_binaries && check_install; } || die "Failed installing node"
}

check_install() {
    white "Checking binaries"
    { check_cardano_cli_install && check_cardano_node_install; } || die "Failed checking binary installation"
}

main() {
    [ -z "${LATEST_VERSION}" ] && red "Couldn't fetch latest node version, try again after making sure you have curl installed" && exit 1
    check_version
    white "Installing the latest cardano-node (${LATEST_VERSION}) and its components to ${WORK_DIR}"
    { find_shell && 
    ask_rc && 
    ask_rc_answer=$? && adjust_rc $ask_rc_answer &&
    install_os_packages &&
    install_latest_node &&
    succeed "Successfully installed latest cardano node! :)"; } || die "Failed installing cardano node :("
}

main