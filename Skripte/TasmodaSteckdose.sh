#!/bin/bash
#
# Andreas Bohne-Lang (2025)
#
# https://github.com/bohnelang
#
# Distributed by CC-BY-NC-SA
#



SET=0
GET=0
MODE=0
IP=0.0.0.0

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -H|--host)
      IP=$2
      shift # past argument
      shift # past value
     ;;
    -s|--set)
      MODE=1
      SET="$2"
      shift # past argument
      shift # past value
      ;;
    -g|--get)
      MODE=2
      GET="$2"
      shift # past argument
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

if test "IP" = "0.0.0.0"
then
	echo "Error: Missing Host IP"
	echo "Usage example: TasmodaSteckdose.sh -H 92.168.1.2:830 --get"
	exit 0
fi

TOGGLE=$(curl -s --connect-timeout 3 --max-time 3 http://$IP/?m=1 | sed -e 's/<[^>]*>//g' | sed s/"{t}"/" "/g | grep -o '\S*$' | sed 's/\([A-Z]\)/\L\1/g'  )	

if test "$TOGGLE" = "" 
then
	echo "Error: Cannot connect IP"
	exit 0
fi

if test $MODE -eq  1 
then

	SET=$(echo $SET | sed 's/\([A-Z]\)/\L\1/g')

	if test "$SET" = "on" ||  test "$SET" = "off"
	then
		if test "$SET" != "$TOGGLE"	
		then
			echo "Set $IP to $SET (http://$IP/?m=1&o=1)"
			curl -s "http://$IP/?m=1&o=1" > /dev/null 2> /dev/null
		fi
	fi
fi 



if test $MODE -eq  2 
then 
	echo $TOGGLE 
fi



if test $MODE -eq  0
then
	echo "Usage: TasmodaSteckdose.sh  -H <HOST IP> --set on --get" 
fi


exit 1

