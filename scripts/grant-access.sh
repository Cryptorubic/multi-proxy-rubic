#!/bin/bash
source .env

load() {

NETWORK=$(cat ./networks | gum filter --placeholder "Network")
ADDRESS=$(gum input --placeholder "Address?")
METHODS=$(gum choose --no-limit 'addDex|0x536db266' 'batchAddDex|0xfcd8e49e' 'removeDex|0x124f1ead' 'batchRemoveDex|0x9afc19c7' 'executCallAndWithdraw|0x1458d7ad'  'setFeeTreasure|0xb395d295' 'setFixedNativeFee|0x6d0f18c4' 'setIntegratorInfo|0x825dc415' 'setMaxRubicPlatformFee|0xbcd97c25' 'setRubicPlatformFee|0x95c54f5a')

ADDRS="deployments/$NETWORK.json"

DIAMOND=$(jq -r '.RubicMultiProxy' $ADDRS)


echo "Updating permissions for $ADDRESS on $NETWORK"
for METHOD in $METHODS
do
  echo "Granting $METHOD"
  grantAccess $NETWORK $DIAMOND $ADDRESS $(echo $METHOD | cut -d'|' -f2)
done
}

grantAccess() {
	NETWORK=$(tr '[:lower:]' '[:upper:]' <<< $1)
  DIAMOND=$2
  ADDRESS=$3
  METHOD=$4
  RPC="ETH_NODE_URI_$NETWORK"

  cast send $DIAMOND 'setCanExecute(bytes4,address,bool)' "$METHOD" "$ADDRESS" true --private-key $PRIVATE_KEY --rpc-url "${!RPC}" --legacy

  echo "Granted!"
}

load
