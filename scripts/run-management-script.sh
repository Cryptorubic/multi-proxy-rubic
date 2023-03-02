#!/bin/bash

run() {
  source .env

  if [[ -z "$PRODUCTION" ]]; then
    FILE_SUFFIX="staging."
  fi

  NETWORK=$(cat ./networks | gum filter --placeholder "Network")

  SCRIPT=$(ls -1 script/management/ | sed -e 's/\.s.sol$//' | gum filter --placeholder "Deploy Script")

  DIAMOND=$(jq -r '.RubicMultiProxy' "./deployments/${NETWORK}.${FILE_SUFFIX}json")
  RPC="ETH_NODE_URI_$(tr '[:lower:]' '[:upper:]' <<< "$NETWORK")"

  RAW_RETURN_DATA=$(NETWORK=$NETWORK FILE_SUFFIX=$FILE_SUFFIX forge script script/management/$SCRIPT.s.sol -f $NETWORK -vvvv --json --silent --broadcast --verify --skip-simulation --legacy)
  echo $RAW_RETURN_DATA
  CLEAN_RETURN_DATA=$(echo $RAW_RETURN_DATA | sed 's/^.*{\"logs/{\"logs/')
  echo $CLEAN__RETURN_DATA | jq 2> /dev/null
  checkFailure
}

checkFailure() {
	if [[ $? -ne 0 ]]; then
		echo "Failed to deploy $CONTRACT"
		exit 1
	fi
}

run
