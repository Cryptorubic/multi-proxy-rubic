#!/bin/bash


update() {
	source .env

	if [[ -z "$PRODUCTION" ]]; then
	  echo 'NOT PRODUCTION SETTINGS'
		FILE_SUFFIX="staging."
	else
	  echo 'PRODUCTION SETTINGS!!!'
	fi

	NETWORK=$(cat ./networks | gum filter --placeholder "Network...")
	SCRIPT=$(ls -1 script | sed -e 's/\.s.sol$//' | grep 'Update' | gum filter --placeholder "Diamond Update Script")
	echo $SCRIPT
	RAW_RETURN_DATA=$(NETWORK=$NETWORK FILE_SUFFIX=$FILE_SUFFIX forge script script/$SCRIPT.s.sol -f $NETWORK -vvvv --json --silent --broadcast --skip-simulation --legacy)
  echo $RAW_RETURN_DATA
	CLEAN_RETURN_DATA=$(echo $RAW_RETURN_DATA | sed 's/^.*{\"logs/{\"logs/')
	RETURN_DATA=$(echo $CLEAN_RETURN_DATA | jq -r '.returns' 2> /dev/null)
  #echo $RETURN_DATA
	echo $CLEAN_RETURN_DATA | jq 2> /dev/null

	facets=$(echo $RETURN_DATA | jq -r '.facets.value')

	saveDiamond $NETWORK "$facets"

  echo "$SCRIPT successfully executed on network $NETWORK"
}

saveDiamond() {
	source .env

	if [[ -z "$PRODUCTION" ]]; then
		FILE_SUFFIX="staging."
	fi

	NETWORK=$1
	FACETS=$(echo $2 | tr -d '[' | tr -d ']' | tr -d ',')
	FACETS=$(printf '"%s",' $FACETS | sed 's/,*$//')

	DIAMOND_FILE="./deployments/${NETWORK}.diamond.${FILE_SUFFIX}json"

	# create an empty json if it does not exist
	if [[ ! -e $DIAMOND_FILE ]]; then
		echo "{}" >"$DIAMOND_FILE"
	fi
	result=$(cat "$DIAMOND_FILE" | jq -r ". + {\"facets\": [$FACETS] }" || cat "$DIAMOND_FILE")
	printf %s "$result" >"$DIAMOND_FILE"
}


update
