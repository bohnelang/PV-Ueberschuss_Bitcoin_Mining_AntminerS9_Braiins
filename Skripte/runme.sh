#!/bin/bash
#
# Andreas Bohne-Lang (2025)
#
# https://github.com/bohnelang
#
# Distributed by CC-BY-NC-SA
#


echo "---------------------------------------------------"
date
echo


#https://hro-netz.de/upgrade-auf-die-letzte-fuer-den-antminer-s9-verfuegbare-braiins-version-2022-09-27-0-26ba61b9-22-08-1-plus-fuer-power_target-parameter-fuer-home-assistant-auf-antminer-s9-nand-setup-problemloesung/

INVERTER_IP=192.168.178.101
ANTMINERS9_IP=192.168.178.110
WIFIPLUG_IP=192.168.1.2:830
INVERTER="./inverter/FroniusSymoGEN24.sh --host $INVERTER_IP"


INVERTER_IP=192.168.1.5
ANTMINERS9_IP=192.168.1.152       ## only an ip not a port forward linke 192.168.1.152:8193  - We need port 80 and 4028
WIFIPLUG_IP=192.168.1.152:8101
INVERTER="./inverter/Kostal.sh --host $INVERTER_IP"


PV_POWERCUT=3000

MINER_MIN=300
MINER_MAX=1300
PDEL=200

MINER_POWERLIMIT=1400 // Do not change unless you know what you are doing...

#-----------------------------------------------------------------------
TIP=$(curl --silent  --connect-timeout 1  http://$INVERTER_IP/ )
if  test "$TIP" = "" 
then
	echo "Inverter at $INVERTER_IP not reachable ... EXIT"
	exit 1
fi

TIP=$(curl --silent  --connect-timeout 1 http://$ANTMINERS9_IP/ )
if  test "$TIP" = "" 
then
        echo "Antminer  at $ANTMINERS9_IP not reachable ... Maybe powerd off. "
fi


PV_POWERCUT=$(echo "scale=0;$PV_POWERCUT-$MINER_MIN+100" | bc)

POSITIONAL_ARGS=()


DRY=0
NOTASMODA=0

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry)
      DRY=1
      shift # past value
      ;;
    --no-tasmoda)
      NOTASMODA=1
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



#
#
# ------------------------------------------------
#
#

TIP=$(curl --silent  --connect-timeout 1 http://$WIFIPLUG_IP/ )
if  test "$TIP" = ""
then
        echo "WifiPlug  at $WIFIPLUG_IP not avalabe  ... "
	NOTASMODA=1
fi



LE=/tmp/PVMLAST.dat


LD=$(date +"%s")
if ! test -e $LE
then
	echo $LD > $LE
fi

LS=$(cat $LE)
LX=$(echo "scale=1;$LD-$LS"| bc )  

if test $LX -le 250 &&  test $DRY -eq 0
then
	echo "Min 5 Min waiting"
	#exit 1
fi

echo $LD > $LE


#
# Reading inverter values
#
while read INVVAL 
do

	if test "$(echo $INVVAL | grep "##+PV##")" != ""
	then
		E_PV=$(echo $INVVAL  |  grep -o '\S*$' )
	fi

	if test "$(echo $INVVAL | grep "##+HOME##")" != ""
	then
		E_HOME=$(echo $INVVAL  |  grep -o '\S*$' )
	fi

	if test "$(echo $INVVAL | grep "##+GRID##")" != ""
	then
		E_GRID=$(echo $INVVAL  |  grep -o '\S*$' )
	fi

	if test "$(echo $INVVAL | grep "##-BATTERYCHARGE##")" != ""
	then
		E_BATTERY_CH=$(echo $INVVAL  |  grep -o '\S*$' )
	fi

	if test "$(echo $INVVAL | grep "##+BATTERYCARGEPERCENT##")" != ""
	then
		E_BATTERY_PER=$(echo $INVVAL  |  grep -o '\S*$' )
	fi


done < <($INVERTER)


# Here we need integer values!

echo
echo "Cast to integer..."
echo "PV    = $E_PV"
echo "HOME  = $E_HOME"
echo "Grid  = $E_GRID"
echo "Bat   = $E_BATTERY_CH"
echo "Charge= $E_BATTERY_PER"
echo 



#
# reading Power Plug 
#
if test $NOTASMODA -eq 0
then
	POWER_PLUG=$(./TasmodaSteckdose.sh --host $WIFIPLUG_IP  --get)
else 	
	POWER_PLUG="on"
fi 

echo
echo "Query Tasmoda/Miner is ... $POWER_PLUG"
echo

#
# Main
#
echo
echo "Checking $E_PV >  $PV_POWERCUT ..." 
echo 

if test $E_PV -le  $PV_POWERCUT && test "$POWER_PLUG" = "off"
then
	echo "Nothing to do..."
	exit 1
fi


if test "$POWER_PLUG" = "off"
then

	if test $E_PV -ge $PV_POWERCUT
	then 
		echo "Miner is $POWER_PLUG -> Power on miner ($E_PV >= $PV_POWERCUT)"
		if test $DRY -eq 0 
		then
			if test $NOTASMODA -eq 0
			then
				./TasmodaSteckdose.sh --host $WIFIPLUG_IP --set on
			fi
		else	
			echo "./TasmodaSteckdose.sh --host $WIFIPLUG_IP --set on"
		fi
	fi
fi

if test "$POWER_PLUG" = "on"
then
	MINER_LIMIT=$(./AntminerS9_SetPower.sh  -H $ANTMINERS9_IP -L root -P "" -Q  | grep "PowerLimit" |  grep -o '\S*$' )
	echo  "Minerpowerlimit: $MINER_LIMIT"

	if test $E_GRID -le $MINER_MIN 
	then
		echo "Shutdown / reduce  due grid or battery consumption (G:$E_GRID /B: $E_BATTERY_CH)"
		if test $DRY -eq 0
                then
			if test $NOTASMODA -eq 0
                        then
                        	./TasmodaSteckdose.sh --host $WIFIPLUG_IP --set off
			else
				if ! test $MINER_LIMIT -eq $MINER_MIN	
				then	
                                	./AntminerS9_SetPower.sh  -H $ANTMINERS9_IP -L root -P "" -W $MINER_MIN
				fi
			fi
                else
                        echo "./TasmodaSteckdose.sh --host $WIFIPLUG_IP --set off"
                fi
		exit 0
	fi

		
	if test $E_PV -le $PV_POWERCUT 
	then
		echo "Miner is $POWER_PLUG -> Power off miner or set minimum($E_PV < $PV_POWERCUT)"
		if test $DRY -eq 0
		then
			if test $NOTASMODA -eq 0
                        then
				./TasmodaSteckdose.sh --host $WIFIPLUG_IP --set off
			else
				if ! test $MINER_LIMIT -eq $MINER_MIN 
				then
					./AntminerS9_SetPower.sh  -H $ANTMINERS9_IP -L root -P "" -W $MINER_MIN
				fi
			fi
		else 	
			echo "./TasmodaSteckdose.sh --host $WIFIPLUG_IP --set off"
		fi
		exit 1
	fi

	#PV_XDelta=$(printf "%.0f" $(echo "scale=1;$E_PV-($E_HOME+$MINER_LIMIT)" | bc ) )
	PV_XDelta=$(printf "%.0f" $(echo "scale=1;$E_PV-($PV_POWERCUT)" | bc ) )

	echo 
	echo "Powerdifferenz: $PV_XDelta"

	if test $PV_XDelta -le $MINER_MIN
	then
		PV_XDelta=$MINER_MIN
	fi

	if test  $PV_XDelta -ge $MINER_MAX
	then
		PV_XDelta=$MINER_MAX
	fi

	echo
        echo "Powerdifferenz for miner: $PV_XDelta"


	W_Delta=$(  printf "%d\n" $( echo "scale=1;$PV_XDelta-$MINER_LIMIT"| bc )  )	 	

	echo
        echo "Schaltdifferenz: $W_Delta $PV_XDelta"


	if test $W_Delta -ge  $PDEL || test $W_Delta -lt -$PDEL
	then 
		echo "Set new power limit to miner: Miner limit old=$MINER_LIMIT, PV_Delta=$PV_XDelta, Delta_set=$W_Delta"
		echo " ./AntminerS9_SetPower.sh  -H $ANTMINERS9_IP -L root -P \"\" -W $PV_XDelta "

		if test $DRY -eq 0
		then
			if test $PV_XDelta -le $MINER_POWERLIMIT 
			then
				echo "Set miner to new power limit from $MINER_LIMIT to mew $PV_XDelta"
				./AntminerS9_SetPower.sh  -H $ANTMINERS9_IP -L root -P "" -W $PV_XDelta 
			else 
				echo "too much power $PV_XDelta -le $MINER_LIMIT "
				exit 1
			fi
		else
			echo "./AntminerS9_SetPower.sh  -H $ANTMINERS9_IP -L root -P "" -W $PV_XDelta"
		fi
	fi
fi
