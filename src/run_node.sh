#!/usr/bin/env bash

workdir="$HOME/cardano"

green() {
    printf "\\033[0;32m%s\\033[0m\\n" "$1"
}

red() {
    printf "\\033[0;31m%s\\033[0m\\n" "$1"
}

white() {
    printf "\033[1;37m%s\\033[0m\\n" "$1"
}

install_cardano_node() {
    ./install_latest_node.sh
}

check_for_installed_cardano_node() {
    white "Checking for installed executable of cardano-node"
    if ! type cardano-node >/dev/null 2>&1
        then 
        red "No cardano-node executable found"
        install_cardano_node
    fi
}

ask_network() {
    while true; do
        white "[M] Mainnet [T] Testnet [?] Help (Default is T)"
        read -r network
		case $network in
			[Tt]* | "") 
                white "Proceeding to run a testnet node"
                network="testnet"
                return 0;;
			[Mm]*)
                white "Proceeding to run a mainnet node"
                network="mainnet"
                return 0;;
			*)
				white "Possible choices are:"
				white "M - Mainnet (default)"
				white "T - Testnet"
				white "Please make your choice and press ENTER." ;;
		esac
	done
	unset network
}

get_mainnet_config_files() {
    green "Fetching cardano blockchain mainnet network configuration files"
    mkdir -p "$workdir"/config/mainnet 
    cd "$workdir"/config/mainnet || exit
    (spinner & wget https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/mainnet-config.json > /dev/null 2>&1 &&
    wget https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/mainnet-byron-genesis.json > /dev/null 2>&1 &&
    wget https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/mainnet-shelley-genesis.json > /dev/null 2>&1 &&
    wget https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/mainnet-topology.json > /dev/null 2>&1 && 
    wget https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/mainnet-alonzo-genesis.json > /dev/null 2>&1)
    touch stopspinning
}

get_testnet_config_files() {
    green "Fetching cardano blockchain testnet network configuration files"
    mkdir -p "$workdir"/config/testnet
    cd "$workdir"/config/testnet|| exit
    (spinner & wget https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/testnet-config.json > /dev/null 2>&1 &&
    wget https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/testnet-byron-genesis.json > /dev/null 2>&1 &&
    wget https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/testnet-shelley-genesis.json > /dev/null 2>&1 &&
    wget https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/testnet-topology.json > /dev/null 2>&1 && 
    wget https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/testnet-alonzo-genesis.json > /dev/null 2>&1)
    touch stopspinning
}

check_for_config_files() {
    white "Checking for config files"
    if ! [ -d "$workdir"/config ]; then
        red "No config files found"
        get_mainnet_config_files
        get_testnet_config_files
    elif ! [ -d "$workdir/config/mainnet" ]; then
        get_mainnet_config_files
    elif ! [ -d "$workdir/config/testnet" ]; then
        get_testnet_config_files
   fi
}

run_cardano_node() {
    green "Preparing to run cardano node"
    ask_network
    config="$workdir/config/$network/$network-config.json"
    db="$workdir/data/db/$network"
    socket="$workdir/ipc/node.socket"
    host="127.0.0.1"
    port=1337
    topology="$workdir/config/$network/$network-topology.json"
    green "Running Cardano Node"
    cardano-node run \
    --config "$config" \
    --database-path "$db" \
    --socket-path "$socket" \
    --host-addr $host \
    --port $port \
    --topology "$topology"
}


main() {
    white "This script runs a cardano node and installs the node if not installed"
    check_for_installed_cardano_node
    check_for_config_files
    run_cardano_node
}

main