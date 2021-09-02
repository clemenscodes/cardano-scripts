#!/bin/sh

CARDANO_WALLET_DIR="$WORK_DIR/cardano-wallet"
LATEST_WALLET_VERSION="$(curl -s "$WALLET_RELEASE_URL" | grep tag_name | awk -F ':' '{print $2}' | tr -d '"' | tr -d ',' | tr -d '[:space:]')"
WALLET_VERSION_PRE_PROCESSED="$(echo "$LATEST_WALLET_VERSION" | tr -d 'v'| tr '-' '.')"
WALLET_YEAR="$(echo "$WALLET_VERSION_PRE_PROCESSED" | awk -F '.' '{print $1}')"
WALLET_MONTH="$(echo "$WALLET_VERSION_PRE_PROCESSED" | awk -F '.' '{print $2}'| tr -d '0')"
WALLET_DAYS="$(echo "$WALLET_VERSION_PRE_PROCESSED" | awk -F '.' '{print $3}')"
WALLET_BINARY="$INSTALL_DIR/cardano-wallet"
WALLET_RELEASE_URL="https://api.github.com/repos/input-output-hk/cardano-wallet/releases/latest"
WALLET_VERSION="$WALLET_YEAR.$WALLET_MONTH.$WALLET_DAYS"
WALLET_BIN_PATH="$CARDANO_WALLET_DIR/dist-newstyle/build/x86_64-linux/ghc-$GHC_VERSION/cardano-wallet-$WALLET_VERSION/x/cardano-wallet/build/cardano-wallet/cardano-wallet"
CARDANO_WALLET_URL="https://github.com/input-output-hk/cardano-wallet.git"
WALLET_PROJECT_FILE="$CARDANO_WALLET_DIR/cabal.project.local"

checkout_latest_wallet_version() {
    white "Checking out latest wallet version"
    change_directory "$CARDANO_WALLET_DIR"
    git fetch --all --recurse-submodules --tags >/dev/null 2>&1
    git checkout tags/"$LATEST_WALLET_VERSION" >/dev/null 2>&1 || die "Failed checking out wallet version $LATEST_WALLET_VERSION"
    green "Successfully checked out latest wallet version $LATEST_WALLET_VERSION"
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


copy_wallet_binary() {
    white "Copying wallet binary to $INSTALL_DIR"
    cp -p "$WALLET_BIN_PATH" "$INSTALL_DIR" || die "Failed copying wallet binary to $INSTALL_DIR"
    green "Successfully copied wallet binary to $INSTALL_DIR"
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

