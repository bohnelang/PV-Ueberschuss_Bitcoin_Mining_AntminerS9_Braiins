#!/bin/bash
#
# Andreas Bohne-Lang (2025)
#
# https://github.com/bohnelang
#
# Distributed by CC-BY-NC-SA
#


MINERIP=192.168.1.148
TMPPATH=/tmp
LOGIN=root
PASSWORD=
POWER=0
MAXPOWER=1200
DEBUG=0
QUERY=0

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -H|--host)
      MINERIP="$2"
      shift # past argument
      shift # past value
      ;;
    -L|--login)
      LOGIN="$2"
      shift # past argument
      shift # past value
      ;;
    -P|--password)
      PASSWORD="$2"
      shift # past argument
      shift # past value
      ;;
    -W|--watt)
      POWER="$2"
      shift # past argument
      shift # past value
      ;;
    -T|--tmppath)
      TMPPATH="$2"
      shift # past argument
      shift # past value
      ;;
    -V|--verbose)
      DEBUG=1
      shift # past argument
      shift # past value
      ;;
    -VV|--vverbose)
     DEBUG=2
     shift # past argument
     shift # past value
     ;;
    -Q|--query)
     QUERY=1
     shift # past argument
     shift # past value
     ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

if test $DEBUG -eq 1
then
	echo "HOST=($MINERIP)"
	echo "LOGIN=($LOGIN)"
	echo "PASSWORD=($PASSWORD)"
	echo "POWER=($POWER)"
	echo "MAXPOWER=($MAXPOWER)"
fi

if test $POWER -gt  $MAXPOWER
then
	if test $DEBUG -eq 1
	then		
		echo "Error POWER ($POWER) > MAXPOWER ($MAXPOWER)"
	fi
	POWER=$MAXPOWER
fi


SESS="$TMPPATH/antminercook_$$.txt"

if test $DEBUG -eq 2 
then
        echo "DEBUG:[$SESS]"
fi


if test -e $SESS 
then 
	rm -f $SESS
fi

#
# LOGIN
#
CULSTR="{\"query\":\"mutation (\$username: String!, \$password: String!) {\n  auth {\n    login(username: \$username, password: \$password) {\n      ... on Error {\n        message\n        __typename\n      }\n      __typename\n    }\n    __typename\n  }\n}\n\",\"variables\":{\"username\":\"$LOGIN\",\"password\":\"$PASSWORD\"}}"

CLOGIN=$(curl -s -c $SESS -H 'Accept: */*' -H 'Content-Type: application/json'  -d "$CULSTR"  "http://$MINERIP/graphql" )

if test $DEBUG -eq 2 
then
	#echo "DEBUG:[$CULSTR]"
	#echo
	echo "DEBUG:[$CLOGIN]"
	echo
fi


if test "$(echo $CLOGIN | grep AuthError)" = "" 
then

#
# SET POWER
#
	if test $POWER -gt 0
	then
	CULSTR="{\"query\":\"mutation (\$tuneInput: AutotuningIn!, \$apply: Boolean!) {\n  bosminer {\n    config {\n      updateAutotuning(input: \$tuneInput, apply: \$apply) {\n        ... on AttributeError {\n          message\n          __typename\n        }\n        ... on AutotuningError {\n          mode\n          message\n          performanceScaling {\n            powerStep\n            shutdownDuration\n            minPowerTarget\n            hashrateStep\n            minHashrateTarget\n            __typename\n          }\n          powerTarget\n          hashrateTarget\n          __typename\n        }\n        ... on AutotuningOut {\n          __typename\n        }\n        __typename\n      }\n      __typename\n    }\n    __typename\n  }\n}\n\",\"variables\":{\"tuneInput\":{\"powerTarget\":$POWER},\"apply\":true}}"

	CPOWER=$(curl -s -b $SESS -H 'Accept: */*' -H 'Content-Type: application/json'  -d "$CULSTR"  "http://$MINERIP/graphql" )

	if test $DEBUG -eq 2 
	then
		#echo "DEBUG:[$CULSTR]"
		#echo
		echo "DEBUG:[$CPOWER]"
		echo
	fi
	fi

#
# Query 
#
	if test $QUERY -eq 1
	then
		MX=$(echo '{"command":"tunerstatus"}' | nc $MINERIP 4028 | tr -d '\0' )
		ApproximateMinerPowerConsumption=$(echo $MX | jq -r .TUNERSTATUS[].ApproximateMinerPowerConsumption )
		ApproximateChainPowerConsumption=$(echo $MX | jq -r .TUNERSTATUS[].ApproximateChainPowerConsumption )
		PowerLimit=$(echo $MX | jq -r .TUNERSTATUS[].PowerLimit )
		echo "ApproximateMinerPowerConsumption: $ApproximateMinerPowerConsumption"
		echo "ApproximateChainPowerConsumption: $ApproximateChainPowerConsumption"
		echo "PowerLimit: $PowerLimit"
		
		MX=$(echo '{"command":"temps"}' | nc $MINERIP 4028 | tr -d '\0' )
		TEMPSBOARD=$(echo $MX | jq -r .TEMPS[].Board )
		TEMPSChip=$(echo $MX | jq -r .TEMPS[].Chip )
		echo "Temp Boards: $TEMPSBOARD"
		echo "Temp Chips: $TEMPSChip"

		MX=$(echo '{"command":"fans"}' | nc $MINERIP 4028 | tr -d '\0' )	
		FANSRPM=$(echo $MX | jq -r .FANS[].RPM )
		echo "Fans: $FANSRPM"
		
		MX=$(echo '{"command":"summary"}' | nc $MINERIP 4028 | tr -d '\0' | sed s/" "//g)	
		HASHRATE=$(echo $MX | jq -r .SUMMARY[].MHS5s )
		HASHRATE=$(echo "scale=2; $HASHRATE/1000000.0"  |  bc)
		echo "Hashrate: $HASHRATE TH/s"
	fi	

#
# LOGOUT
#
	CULSTR="{\"query\":\"mutation {\n  auth {\n    logout {\n      ... on Error {\n        message\n        __typename\n      }\n      __typename\n    }\n    __typename\n  }\n}\n\",\"variables\":{}}"
	
	CLOGOUT=$(curl -s -b $SESS -H 'Accept: */*' -H 'Content-Type: application/json'  -d "$CULSTR"  "http://$MINERIP/graphql" )
	if test $DEBUG -eq 2 
	then
        	echo "DEBUG:[$CPOWER]"
	fi
else
	echo "Login faild"
fi

rm -f $SESS

