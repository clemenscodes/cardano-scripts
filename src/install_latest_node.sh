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


# Source: https://github.com/swelljoe/spinner
spinner () {
    SPINNER_COLORNUM=2 
    SPINNER_COLORCYCLE=1 
    SPINNER_DONEFILE="stopspinning" 
    SPINNER_SYMBOLS="ASCII_PROPELLER"
    SPINNER_CLEAR=1 
    # shellcheck disable=SC2034
    ASCII_PROPELLER="/ - \\ |"
    SPINNER_NORMAL=$(tput sgr0)
    eval SYMBOLS=\$${SPINNER_SYMBOLS}
    SPINNER_PPID=$(ps -p "$$" -o ppid=)
    while :; do
        tput civis
        for c in ${SYMBOLS}; do
            if [ $SPINNER_COLORCYCLE -eq 1 ]; then
                if [ $SPINNER_COLORNUM -eq 7 ]; then
                    SPINNER_COLORNUM=1
                else
                    SPINNER_COLORNUM=$((SPINNER_COLORNUM+1))
                fi
            fi
            COLOR=$(tput setaf ${SPINNER_COLORNUM})
            tput sc
            env printf "${COLOR}${c}${SPINNER_NORMAL}"
            tput rc
            if [ -f "${SPINNER_DONEFILE}" ]; then
                if [ ${SPINNER_CLEAR} -eq 1 ]; then
                    tput el
                fi
                rm ${SPINNER_DONEFILE}
                break 2
            fi
            env sleep .2
            if [ -n "$SPINNER_PPID" ]; then
                # shellcheck disable=SC2086
                SPINNER_PARENTUP=$(ps --no-headers $SPINNER_PPID)
                if [ -z "$SPINNER_PARENTUP" ]; then
                    break 2
                fi
            fi
        done
    done
    tput cnorm
    return 0
}

# Source: https://github.com/swelljoe/spinner
# Handle signals
cleanup () {
	tput rc
	tput cnorm
	return 1
}

# Source: https://github.com/swelljoe/spinner
# This tries to catch any exit, to reset cursor
trap cleanup INT QUIT TERM

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
        read -r rc_answer </dev/tty
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
    ld=$(grep LD_LIBRARY_PATH "${SHELL_PROFILE_FILE}")
    pkg=$(grep PKG_CONFIG_PATH "${SHELL_PROFILE_FILE}")
    bin=$(grep .local/bin/ "${SHELL_PROFILE_FILE}")
    socket=$(grep CARDANO_NODE_SOCKET_PATH "${SHELL_PROFILE_FILE}")
    [ -z "${ld}" ] && echo 'export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"' >> "${SHELL_PROFILE_FILE}"
    [ -z "${pkg}" ] && echo 'export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"' >> "${SHELL_PROFILE_FILE}"
    [ -z "${bin}" ] && echo 'export PATH="$HOME/.local/bin/:$PATH"' >> "${SHELL_PROFILE_FILE}"
    [ -z "${socket}" ] && echo 'export CARDANO_NODE_SOCKET_PATH="$HOME/cardano/db/node.socket"' >> "${SHELL_PROFILE_FILE}"
}

adjust_rc() {
    case $1 in
		1) check_for_path_variables ;;
		*) ;;
	esac
}

get_root_privileges() {
    white "This script requires root privileges"
    sudo echo > /dev/null
}

install_os_packages() {
    dist=$(lsb_release -is)
    case "${dist}" in 
        Fedora*|Hat*|CentOs*)
            white "Updating and installing operating system dependencies"
            (spinner & sudo yum update -y > /dev/null 2>&1 
            sudo yum install git gcc gcc-c++ tmux gmp-devel make tar xz wget zlib-devel libtool autoconf -y > /dev/null 2>&1
            sudo yum install systemd-devel ncurses-devel ncurses-compat-libs -y > /dev/null 2>&1
            touch stopspinning) ;;
        Ubuntu*|Debian*)
            white "Updating and installing operating system dependencies"
            (spinner & sudo apt-get update -y > /dev/null 2>&1
            sudo apt-get install automake build-essential pkg-config libffi-dev libgmp-dev libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev make g++ tmux git jq wget libncursesw5 libtool autoconf -y > /dev/null;
            touch stopspinning) ;;
        *) red "Unsupported operating system :(" && exit 1
    esac
}

install_nix() {
    red "Nix is not installed, proceeding to install Nix"
    curl -L https://nixos.org/nix/install > install-nix.sh
    chmod +x install-nix.sh
    ./install-nix.sh
    rm ./install-nix.sh
}

set_nix_iohk_build_cache() {
    green "Setting IOHK build cache"
    sudo mkdir -p /etc/nix
    cat << EOF | sudo tee /etc/nix/nix.conf
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
    curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
}

check_ghcup() {
    white "Checking for ghcup"
    if ! type ghcup > /dev/null 2>&1; then 
        install_ghcup
    fi
}

install_ghc() {
    white "Installing GHC 8.10.4"
    ghcup install ghc 8.10.4
    ghcup set ghc 8.10.4
}

check_ghc() {
    white "Checking for GHC"
    if ! type ghc > /dev/null 2>&1; then 
        install_ghc
    fi 
}

check_cabal() {
    white "Checking for Cabal"
    if ! type cabal > /dev/null 2>&1; then 
        red "Cabal is not installed properly"
        install_ghcup  
    fi 
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
    (spinner & git clone https://github.com/input-output-hk/libsodium > /dev/null 2>&1
    touch stopspinning)
    green "Downloaded libsodium"
}

install_libsodium() {
    download_libsodium
    white "Installing libsodium to ${WORK_DIR}"
    cd libsodium || exit
    (spinner & git checkout 66f017f1 > /dev/null 2>&1
    ./autogen.sh > /dev/null 2>&1
    ./configure > /dev/null 2>&1
    make > /dev/null 2>&1
    sudo make install > /dev/null 2>&1 
    touch stopspinning)
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
        (spinner & git clone https://github.com/input-output-hk/cardano-node.git > /dev/null 2>&1
        touch stopspinning)
        green "Downloaded cardano-node repository"
    else 
        green "cardano-node repository found, skip pulling"
    fi 
}

download_cardano_db_sync_repository() {
    if ! [ -d "${WORK_DIR}/cardano-db-sync" ]; then
        white "Downloading cardano-db-sync repository"
        (spinner & git clone https://github.com/input-output-hk/cardano-db-sync.git > /dev/null 2>&1
        touch stopspinning)
        green "Downloaded cardano-db-sync repository"
    else
        green "cardano-db-sync repository found, skip pulling"
    fi 
}

create_db_folder() {
    if ! [ -d "${WORK_DIR}/db" ]; then 
        white "Adding db folder to working directory"
        mkdir -p "${WORK_DIR}"/db
        green "Created db folder"
    else 
        green "db folder found, skip creating"
    fi
}

download_cardano_repositories_to_workdir() {
    cd "${WORK_DIR}" || exit 
    download_cardano_node_repository
    download_cardano_db_sync_repository
    create_db_folder
}

checkout_latest_node_version() {
    cd "${WORK_DIR}"/cardano-node || exit
    white "Fetching latest node version"
    latest_node_version=$(curl -s https://api.github.com/repos/input-output-hk/cardano-node/releases/latest | grep '"tag_name":' |  sed -E 's/.*"([^"]+)".*/\1/' > /dev/null 2>&1) 
    git checkout tags/"${latest_node_version}" > /dev/null 2>&1
    green "Successfully checked out latest node version $latest_node_version"
}

configure_build_options() {
    white "Configuring the build options to build with GHC version 8.10.4"
    (spinner & cabal configure --with-compiler=ghc-8.10.4 > /dev/null 2>&1)
    touch stopspinning
    green "Configured build options"
}

update_local_project_file_to_use_libsodium_compiler() {
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
    (spinner & cabal build all > /dev/null 2>&1)
    touch stopspinning
}

check_for_binary_install_directory() {
    if ! [ -d "$HOME"/.local/bin ]; then 
        mkdir -p "$HOME"/.local/bin
    fi
}

installing_binaries_to_local_bin() {
    white "Installing the binaries to $HOME/.local/bin"
    check_for_binary_install_directory
    cp -p "$(./scripts/bin-path.sh cardano-node)" "$HOME"/.local/bin/
    cp -p "$(./scripts/bin-path.sh cardano-cli)" "$HOME"/.local/bin/
}

check_cardano_cli_installation() {
    white "Checking cardano-cli installation"
    if ! [ -f "$HOME/.local/bin/cardano-cli" ]; then 
        red "Failed installing cardano-cli"
        exit 1
        else
        green "Successfully installed cardano-cli"
    fi
}

check_cardano_node_installation() {
    white "Checking cardano-node installation"
    if ! [ -f "$HOME/.local/bin/cardano-node" ]; then 
        red "Failed installing cardano-node"
        exit 1
        else
        green "Successfully installed cardano-node"
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