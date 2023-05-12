#!/bin/bash

deploy() {
	source .env

	if [[ -z "$PRODUCTION" ]]; then
		FILE_SUFFIX="staging."
	fi

	NETWORK=$(cat ./networks | gum filter --placeholder "Network")
	SCRIPT=$(ls -1 deploy | sed -e 's/\.ts$//' | grep 'deploy' | gum filter --placeholder "Deploy Script")
	CONTRACT=$(echo $SCRIPT | sed -e 's/deploy//')

	echo $SCRIPT

	RAW_RETURN_DATA=$(yarn hardhat deploy-zksync --script deploy/$SCRIPT.ts)
  #echo $RAW_RETURN_DATA
	CLEAN_RETURN_DATA=$(echo $RAW_RETURN_DATA | sed 's/^.*{"address/{"address/')
	CLEAN_RETURN_DATA=$(echo $CLEAN_RETURN_DATA | sed 's/}.*$/}/')
	#echo $CLEAN_RETURN_DATA
	checkFailure

	deployed=$(echo $CLEAN_RETURN_DATA | jq -r '.address')
	args=$(echo $CLEAN_RETURN_DATA | jq -r '.constructorArgs // "0x"')

	echo "$CONTRACT deployed on $NETWORK at address $deployed with args: $args"

	saveContract $NETWORK $CONTRACT $deployed
	#verifyContract $NETWORK $CONTRACT $deployed $args
}

saveContract() {
	source .env

	if [[ -z "$PRODUCTION" ]]; then
		FILE_SUFFIX="staging."
	fi

	NETWORK=$1
	CONTRACT=$2
	ADDRESS=$3

	ADDRESSES_FILE="./deployments/${NETWORK}.${FILE_SUFFIX}json"

	# create an empty json if it does not exist
	if [[ ! -e $ADDRESSES_FILE ]]; then
		echo "{}" >"$ADDRESSES_FILE"
	fi
	result=$(cat "$ADDRESSES_FILE" | jq -r ". + {\"$CONTRACT\": \"$ADDRESS\"}" || cat "$ADDRESSES_FILE")
	printf %s "$result" >"$ADDRESSES_FILE"
}

verifyContract() {
	source .env

	NETWORK=$1
	CONTRACT=$2
	ADDRESS=$3
	ARGS=$4
	API_KEY="$(tr '[:lower:]' '[:upper:]' <<< $NETWORK)_ETHERSCAN_API_KEY"
	if [ "$ARGS" = "" ]; then
		yarn hardhat verify --network $NETWORK $ADDRESS --contract "src/Facets/$CONTRACT.sol:$CONTRACT"
	else
	  yarn hardhat verify --network $NETWORK $ADDRESS
	fi
}

checkFailure() {
	if [[ $? -ne 0 ]]; then
		echo "Failed to deploy $CONTRACT"
		exit 1
	fi
}

deploy
