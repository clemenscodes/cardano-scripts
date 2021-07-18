#!/usr/bin/env bash

workdir="$HOME/cardano"
RED='\033[0;31m'    
GREEN='\033[0;32m'    
SET='\033[0m'

install_cardano_node() {
    ./install-latest-node.sh
}

check_for_installed_cardano_node() {
    echo -e "${GREEN}Checking for installed executable of cardano-node${SET}"
    if ! type cardano-node >/dev/null 2>&1
        then 
        echo -e "${RED}No cardano-node executable found${SET}"
        install_cardano_node
    fi
}

get_mainnet_config_files() {
    echo -e "${GREEN}Fetching cardano blockchain mainnet network configuration files${SET}"
    mkdir -p "$workdir"/config/mainnet 
    cd "$workdir"/config/mainnet || exit
    wget https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/mainnet-config.json
    wget https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/mainnet-byron-genesis.json
    wget https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/mainnet-shelley-genesis.json
    wget https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/mainnet-topology.json
}

get_testnet_config_files() {
    echo -e "${GREEN}Fetching cardano blockchain testnet network configuration files${SET}"
    mkdir -p "$workdir"/config/testnet
    cd "$workdir"/config/testnet|| exit
    wget https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/testnet-config.json
    wget https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/testnet-byron-genesis.json
    wget https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/testnet-shelley-genesis.json
    wget https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/testnet-topology.json
}

check_for_config_files() {
    echo -e "${GREEN}Checking for config files${SET}"
    if ! [ -d "$workdir"/config ]
        then 
        echo -e "${RED}No config files found${SET}"
        get_mainnet_config_files
        get_testnet_config_files
   fi
}


check_for_cardano_socket_path_in_bashrc() {
    echo -e "${GREEN}Checking for CARDANO_NODE_SOCKET_PATH in $HOME/.bashrc${SET}"
    socket_in_bashrc=$(cat $HOME/.bashrc | grep CARDANO)
    if [ -z "${socket_in_bashrc}" ]
        then 
        echo -e "${GREEN}Setting CARDANO_NODE_SOCKET_PATH ENV for IPC to $HOME/.bashrc${SET}"
        echo 'export CARDANO_NODE_SOCKET_PATH="$HOME/cardano/db/node.socket"' >> "$HOME"/.bashrc
    fi 
}
 
check_for_cardano_socket_path_in_zshrc() {
    echo -e "${GREEN}Checking for CARDANO_NODE_SOCKET_PATH $HOME/.zshrc${SET}"
    socket_in_zshrc=$(cat $HOME/.zshrc | grep CARDANO)
    if [ -z "${socket_in_zshrc}" ]
        then 
        echo -e "${GREEN}Setting CARDANO_NODE_SOCKET_PATH ENV for IPC to $HOME/.zshrc${SET}"
        echo 'export CARDANO_NODE_SOCKET_PATH="$HOME/cardano/db/node.socket"' >> "$HOME"/.zshrc
    fi 
}

check_for_cardano_socket_path() {
    echo -e "${GREEN}Checking for the CARDANO_NODE_SOCKET_PATH ENV for IPC${SET}"
    check_for_cardano_socket_path_in_bashrc
    check_for_cardano_socket_path_in_zshrc
}

run_cardano_node() {
    echo -e "${GREEN}Preparing to run cardano node${SET}"
    config="$workdir/config/testnet/testnet-config.json"
    db="$workdir/db"
    socket="$workdir/db/node.socket"
    host="127.0.0.1"
    port=1337
    topology="$workdir/config/testnet/testnet-topology.json"
    echo -e "${GREEN}Running Cardano Node${SET}"
    cardano-node run \
    --config "$config" \
    --database-path "$db" \
    --socket-path "$socket" \
    --host-addr $host \
    --port $port \
    --topology "$topology"
}

run() {
    echo -e "${GREEN}This script runs a cardano node and installs the node if not installed${SET}"
    check_for_installed_cardano_node
    check_for_config_files
    check_for_cardano_socket_path
    run_cardano_node
}

run