#!/bin/bash
source .env

if [[ -z "$PRODUCTION" ]]; then
  echo 'NOT PRODUCTION SETTINGS'
  FILE_SUFFIX="staging."
else
  echo 'PRODUCTION SETTINGS!!!'
fi

NETWORK=$(cat ./networks | gum filter --placeholder "Network")

echo 'adding sigs on $NETWORK...'

DIAMOND=$(jq -r '.RubicMultiProxy' "./deployments/${NETWORK}.${FILE_SUFFIX}json")
CFG_SIGS=($(jq -r '.[] | @sh' "./config/sigs.json" | tr -d \' | tr '[:upper:]' '[:lower:]' ))

RPC="ETH_NODE_URI_$(tr '[:lower:]' '[:upper:]' <<< "$NETWORK")"


echo 'Updating Sigs'
for d in "${CFG_SIGS[@]}"; do
  PARAMS+="${d},"
done
cast send $DIAMOND "batchSetFunctionApprovalBySignature(bytes4[],bool)" "[${PARAMS::-1}]" true --rpc-url ${!RPC} --private-key ${PRIVATE_KEY} --legacy
