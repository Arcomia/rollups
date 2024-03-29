#!/bin/sh

# set variables for the chain
VALIDATOR_NAME=validator1
CHAIN_ID=rcm
KEY_NAME=rcm-key
KEY_2_NAME=rcm-key-2
CHAINFLAG="--chain-id ${CHAIN_ID}"
TOKEN_AMOUNT="10000000000000000000000000arcomia"
STAKING_AMOUNT="1000000000arcomia"

# query the DA Layer start height, in this case we are querying
# an RPC endpoint provided by Celestia Labs. The RPC endpoint is
# to allow users to interact with Celestia's core network by querying
# the node's state and broadcasting transactions on the Celestia
# network. This is for Arabica, if using another network, change the RPC.
DA_BLOCK_HEIGHT=$(curl https://rpc.lunaroasis.net/block | jq -r '.result.block.header.height')
echo -e "\n Your DA_BLOCK_HEIGHT is $DA_BLOCK_HEIGHT \n"

# build the rcm chain with Rollkit
ignite chain build

# reset any existing genesis/chain data
rcmd tendermint unsafe-reset-all

# initialize the validator with the chain ID you set
rcmd init $VALIDATOR_NAME --chain-id $CHAIN_ID

# add keys for key 1 and key 2 to keyring-backend test
rcmd keys add $KEY_NAME --keyring-backend test
rcmd keys add $KEY_2_NAME --keyring-backend test

# add these as genesis accounts
rcmd genesis add-genesis-account $KEY_NAME $TOKEN_AMOUNT --keyring-backend test
rcmd genesis add-genesis-account $KEY_2_NAME $TOKEN_AMOUNT --keyring-backend test

# set the staking amounts in the genesis transaction
rcmd genesis gentx $KEY_NAME $STAKING_AMOUNT --chain-id $CHAIN_ID --keyring-backend test

# collect genesis transactions
rcmd genesis collect-gentxs

# copy centralized sequencer address into genesis.json
# Note: validator and sequencer are used interchangeably here
ADDRESS=$(jq -r '.address' ~/.rcm/config/priv_validator_key.json)
PUB_KEY=$(jq -r '.pub_key' ~/.rcm/config/priv_validator_key.json)
jq --argjson pubKey "$PUB_KEY" '.consensus["validators"]=[{"address": "'$ADDRESS'", "pub_key": $pubKey, "power": "1000", "name": "Rollkit Sequencer"}]' ~/.rcm/config/genesis.json > temp.json && mv temp.json ~/.rcm/config/genesis.json

# create a restart-mainnet.sh file to restart the chain later
[ -f restart-mainnet.sh ] && rm restart-mainnet.sh
echo "DA_BLOCK_HEIGHT=$DA_BLOCK_HEIGHT" >> restart-mainnet.sh

echo "rcmd start --rollkit.aggregator --rollkit.da_address=":26650" --rollkit.da_start_height \$DA_BLOCK_HEIGHT --rpc.laddr tcp://127.0.0.1:36657 --grpc.address 127.0.0.1:9290 --p2p.laddr \"0.0.0.0:36656\" --minimum-gas-prices="0.025arcomia"" >> restart-mainnet.sh

# start the chain
rcmd start --rollkit.aggregator --rollkit.da_address=":26650" --rollkit.da_start_height $DA_BLOCK_HEIGHT --rpc.laddr tcp://127.0.0.1:36657 --grpc.address 127.0.0.1:9290 --p2p.laddr "0.0.0.0:36656" --minimum-gas-prices="0.025arcomia"