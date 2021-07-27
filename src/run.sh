#!/bin/sh

unset NETWORK

RUNNER="${SUDO_USER:-$USER}"
USER_HOME="/home/$RUNNER"
WORK_DIR="$USER_HOME/.cardano"
IPC_DIR="$WORK_DIR/ipc"
CONFIG_DIR="$WORK_DIR/config"
DATA_DIR="$WORK_DIR/data/db"
CONFIG_BASE_URL="https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1"
RELEASE_URL="https://api.github.com/repos/input-output-hk/cardano-node/releases/latest"
LATEST_VERSION="$(curl -s "$RELEASE_URL" | grep tag_name | awk -F ':' '{print $2}' | tr -d '"' | tr -d ',' | tr -d '[:space:]')"
NODE_INSTALL_URL="https://cardano-scripts.web.app/"
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

help() {
    normal "Usage:   run.sh [ [ -t | -m ] | [ -h | -v ] ]"
    normal 
    normal "This script runs the latest cardano node version"
    normal 
    normal "Available options"
    normal "  -t, --testnet           Runs the node in testnet"
    normal "  -m, --mainnet           Runs the node in mainnet"
    normal "  -p, --pipeline          Runs the node for 30 seconds and then kills the process"
    normal "  -h, --help              Display this help message"
    normal "  -v, --version           Display the latest cardano node version"
}

usage() {
    help && exit 1
}

check_arguments() {
    while [ "$#" -gt 0 ]; do
    case $1 in
        -h|--help) help && exit 0 ;;
        -v|--version) version;;
        -p|--pipeline) pipeline;;
        -m|--mainnet) mainnet;;
        -t|--testnet) testnet;;
        *) red "Unknown parameter passed: $1" && usage ;;
    esac
    shift
    done
}

pipeline() {
    if [ -z "$PIPELINE" ]; then 
        PIPELINE=true
    else 
        red "Don't use optional flags multiple times" && usage
    fi
}

mainnet() {
    if [ -z "$NETWORK" ]; then 
        NETWORK="mainnet"
    else 
        red "Don't use optional flags multiple times" && usage
    fi
}

testnet() {
    if [ -z "$NETWORK" ]; then 
        NETWORK="testnet"
    else 
        red "Don't use optional flags multiple times" && usage
    fi
}

version() {
    normal "$LATEST_VERSION" && exit 0 
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

check_version() {
    [ -z "$LATEST_VERSION" ] && red "Couldn't fetch latest node version, try again after making sure you have curl installed" && exit 1
    if type cardano-node >/dev/null 2>&1; then 
        installed_cardano_node_version=$(cardano-node --version | awk '{print $2}'| head -n1)
        if [ "$installed_cardano_node_version" = "$LATEST_VERSION" ]; then 
            purple "Latest cardano-node binary is installed (v$LATEST_VERSION)" && return 0;
        else 
            yellow "Updating cardano-node version $installed_cardano_node_version to version $LATEST_VERSION"
            install_node || die "Failed updating node to $LATEST_VERSION"
        fi
    else 
        install_node || die "Failed updating node to $LATEST_VERSION"
    fi 
}

install_node() {
    ({
    white "Installing latest cardano node"
    export CONFIRM=true 
    export VERBOSE=true
    curl --proto '=https' --tlsv1.2 -sSf "$NODE_INSTALL_URL" | sh # >/dev/null 2>&1
    } || die "Failed installing latest cardano node")
}

check_network() {
    [ -z "$NETWORK" ] || { purple "Selected $NETWORK network" && return 0; }
    while true; do
        white "[t] Testnet [m] Mainnet [?] Help (Default is t)"
        read -r NETWORK 
		case $NETWORK in
			[Tt]* | "") 
                white "Proceeding to run a testnet node"
                NETWORK="testnet"
                return 0;;
			[Mm]*)
                white "Proceeding to run a mainnet node"
                NETWORK="mainnet"
                return 0;;
			*)
				white "Possible choices are:"
				white "t - Testnet (default)"
				white "m - Mainnet"
				white "Please make your choice and press ENTER." ;;
		esac
	done
}

check_config() {
    white "Checking for $NETWORK config files"
    check_directory "config" "$CONFIG_DIR"
    check_directory "$NETWORK" "$CONFIG_DIR/$NETWORK"
    check_config_files "$NETWORK" "$CONFIG_DIR/$NETWORK"
}

check_config_files() {
    green "Checking cardano $1 configuration files"
    check_directory "$1" "$2"
    change_directory "$2"
    check_file "$1" "config"
    check_file "$1" "byron-genesis"
    check_file "$1" "shelley-genesis"
    check_file "$1" "alonzo-genesis"
    check_file "$1" "topology"
}

check_file() {
    if ! [ -f "$CONFIG_DIR/$NETWORK/${1}-${2}.json" ]; then
        red "${1}-${2}.json file not found, fetching it"
        wget "$CONFIG_BASE_URL/${1}-${2}.json" >/dev/null 2>&1 || die "Failed fetching ${1}-${2}.json file"
        green "Fetched ${1}-${2}.json file successfully"
    else 
        green "${1}-${2}.json file found"
    fi
}

check_ownerships() {
    if [ "$(id -u)" -eq 0 ]; then 
        set_ownership "$CONFIG_DIR"
        set_ownership "$DATA_DIR"
        set_ownership "$SOCKET"
    fi
}

set_ownership() {
    chown -R "$RUNNER":"$RUNNER" "$1"
}

run() {
    green "Preparing to run node"
    [ -z "$NETWORK" ] && ask_network
    green "Running node in $NETWORK"
    if [ -z "$PIPELINE" ]; then
        CONFIG="$CONFIG_DIR/$NETWORK/$NETWORK-config.json"
        DB="$DATA_DIR/$NETWORK"
        SOCKET="$IPC_DIR/node.socket"
        HOST="127.0.0.1"
        PORT=1337
        TOPOLOGY="$CONFIG_DIR/$NETWORK/$NETWORK-topology.json"
        cardano-node run \
        --config "$CONFIG" \
        --database-path "$DB" \
        --socket-path "$SOCKET" \
        --host-addr $HOST \
        --port $PORT \
        --topology "$TOPOLOGY" 
    else
        yellow "Pipelined node"
        CONFIG="$CONFIG_DIR/$NETWORK/$NETWORK-config.json"
        DB="$DATA_DIR/$NETWORK"
        SOCKET="$IPC_DIR/node.socket"
        HOST="127.0.0.1"
        PORT=1337
        TOPOLOGY="$CONFIG_DIR/$NETWORK/$NETWORK-topology.json"
        cardano-node run \
        --config "$CONFIG" \
        --database-path "$DB" \
        --socket-path "$SOCKET" \
        --host-addr $HOST \
        --port $PORT \
        --topology "$TOPOLOGY" & PID=$! && sleep 30 && kill -HUP $PID
    fi
}

main() {
    check_arguments "$@"
    check_version
    check_network
    check_config
    check_ownerships
    run
}

main "$@"