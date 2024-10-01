#!/bin/bash

run() {
  source .env

  if [[ -z "$PRODUCTION" ]]; then
	  echo 'NOT PRODUCTION SETTINGS'
		FILE_SUFFIX="staging."
	else
	  echo 'PRODUCTION SETTINGS!!!'
	fi

  NETWORK=$(cat ./networks | gum filter --placeholder "Network")

  SCRIPT=$(ls -1 script/management/ | sed -e 's/\.s.sol$//' | gum filter --placeholder "Deploy Script")

  echo "running on ${NETWORK}..."

  echo $SCRIPT

  DIAMOND=$(jq -r '.RubicMultiProxy' "./deployments/${NETWORK}.${FILE_SUFFIX}json")
  RPC="ETH_NODE_URI_$(tr '[:lower:]' '[:upper:]' <<< "$NETWORK")"

  RAW_RETURN_DATA=$(NETWORK=$NETWORK FILE_SUFFIX=$FILE_SUFFIX forge script script/management/$SCRIPT.s.sol -f $NETWORK --json --silent --broadcast --skip-simulation --legacy)
  checkFailure
  CLEAN_RETURN_DATA=$(echo $RAW_RETURN_DATA | sed 's/^.*{\"logs/{\"logs/')
  echo $CLEAN_RETURN_DATA | jq '.returns' 2> /dev/null
}

checkFailure() {
	if [[ $? -ne 0 ]]; then
		echo "Failed to deploy $CONTRACT"
		exit 1
	fi
}

run
