#!/usr/bin/env sh
echo
echo "Checking for installed executable of cardano-node"
echo

if ! type cardano-node > /dev/null; 
then 
./install-latest-node.sh
fi

echo
echo "Preparing to run Cardano Node"
echo
echo "Working in $HOME/cardano"

workdir="$HOME/cardano"

cd "$workdir" || exit

echo
echo "Checking for config files"
echo

if ! [ -d "$workdir"/config ]; then 

    echo
    echo "No config files found"
    echo
    echo "Obtaining Cardano Blockchain Mainnet Network Configuration files"
    echo

    mkdir -p "$workdir"/config/mainnet 

    cd "$workdir"/config/mainnet || exit

    wget https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/mainnet-config.json
    wget https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/mainnet-byron-genesis.json
    wget https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/mainnet-shelley-genesis.json
    wget https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/mainnet-topology.json

    echo
    echo "Obtaining Cardano Blockchain Testnet Network Configuration files"
    echo

    mkdir -p "$workdir"/config/testnet

    cd "$workdir"/config/testnet|| exit

    wget https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/testnet-config.json
    wget https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/testnet-byron-genesis.json
    wget https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/testnet-shelley-genesis.json
    wget https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/testnet-topology.json

fi

socket_in_bashrc=$(cat $HOME/.bashrc | grep CARDANO)
socket_in_zshrc=$(cat $HOME/.zshrc | grep CARDANO)

echo
echo "Checking for the CARDANO_NODE_SOCKET_PATH ENV for IPC"
echo

if [ -z "${socket_in_bashrc}" ]
    then 
    echo "Setting CARDANO_NODE_SOCKET_PATH ENV for IPC to $HOME/.bashrc"
    echo 'export CARDANO_NODE_SOCKET_PATH="$HOME/cardano/db/node.socket"' >> "$HOME"/.bashrc
fi 

if [ -z "${socket_in_zshrc}" ]
    then 
    echo "Setting CARDANO_NODE_SOCKET_PATH ENV for IPC to $HOME/.zshrc"
    echo 'export CARDANO_NODE_SOCKET_PATH="$HOME/cardano/db/node.socket"' >> "$HOME"/.zshrc
fi 

echo
echo "Running the node"
echo

config="$workdir/config/testnet/testnet-config.json"
db="$workdir/db"
socket="$workdir/db/node.socket"
host="127.0.0.1"
port=1337
topology="$workdir/config/testnet/testnet-topology.json"

cardano-node run \
--config "$config" \
--database-path "$db" \
--socket-path "$socket" \
--host-addr $host \
--port $port \
--topology "$topology"
