#!/bin/bash

FUNCTION="startBridgeTokensViaGenericCrossChain((bytes32,string,address,address,address,address,address,address,uint256,uint256,bool,bool),(address,address,uint256,bytes))"
TX_ID=0x605b931aa156dc4ed33fcf7cabeb532761b494f7ac21e6353d63cb54020795fd
BRIDGE=gcc
INTEGRATOR=0x0000000000000000000000000000000000000000
REFERRER=0x0000000000000000000000000000000000000000
SENDING_ASSET_ID=0x55d398326f99059ff775485246999027b3197955
RECEIVING_ASSET_ID=0x0000000000000000000000000000000000000000
RECEIVER=0xbeefbeefbeefbeefbeefbeefbeefbeefbeefbeef
REFUNDEE=0xbeefbeefbeefbeefbeefbeefbeefbeefbeefbeef
MIN_AMOUNT=100000000000000000000
DST_CHAIN_ID=1

TARGET_ADDRESS=0x13e46b2a3f8512ed4682a8fb8b560589fe3c2172
APPROVE_TO=0x13e46b2a3f8512ed4682a8fb8b560589fe3c2172
EXTRA_NATIVE=0
DATA=`cat scripts/data.txt | tr -d '\n'`

die() {
    printf '%s\n' "$1" >&2
    exit 1
}

while :; do
    case $1 in
        -h|-\?|--help)
            echo "help"    # Display a usage synopsis.
            exit
            ;;
        -f|--with-fee)       # Takes an option argument; ensure it has been specified.
            INTEGRATOR=0xbEF9344Defc4e5E5C07B5D60d38AaA49B48fb7e0
            ;;
        -a|--asset)       # Takes an option argument; ensure it has been specified.
            if [ "$2" ]; then
                SENDING_ASSET_ID=$2
                shift
            else
                die 'ERROR: "--asset" requires a non-empty option argument.'
            fi
            ;;
        --amount)       # Takes an option argument; ensure it has been specified.
            if [ "$2" ]; then
                MIN_AMOUNT=$2
                shift
            else
                die 'ERROR: "--amount" requires a non-empty option argument.'
            fi
            ;;
        --address)       # Takes an option argument; ensure it has been specified.
            if [ "$2" ]; then
                TARGET_ADDRESS=$2
                shift
            else
                die 'ERROR: "--address" requires a non-empty option argument.'
            fi
            ;;
#        --data)       # Takes an option argument; ensure it has been specified.
#            if [ "$2" ]; then
#                DATA=$2
#                shift
#            else
#                die 'ERROR: "--data" requires a non-empty option argument.'
#            fi
#            ;;
        --)              # End of all options.
            shift
            break
            ;;
        -?*)
            printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
            ;;
        *)               # Default case: No more options, so break out of the loop.
            break
    esac

    shift
done

BRIDGE_DATA="($TX_ID,$BRIDGE,$INTEGRATOR,$REFERRER,$SENDING_ASSET_ID,$RECEIVING_ASSET_ID,$RECEIVER,$REFUNDEE,$MIN_AMOUNT,$DST_CHAIN_ID,false,false)"

CALLDATA=`cast ae $FUNCTION $BRIDGE_DATA "($TARGET_ADDRESS,$APPROVE_TO,$EXTRA_NATIVE,$DATA)" | cut -c 3-`

echo "0x647eb57e"$CALLDATA
