#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""

Andreas Kleber https://github.com/akleber/fronius-json-tools/

Queries some API endpoints for the most important data and saves it to a sqlite database
for easy access. Should be run regularly, e.g. every 5 minutes.

get_example("/solar_api/v1/GetActiveDeviceInfo.cgi?DeviceClass=System")
get_example("/solar_api/v1/GetInverterInfo.cgi")
get_example("/solar_api/v1/GetInverterRealtimeData.cgi?Scope=System")
get_example("/solar_api/v1/GetLoggerInfo.cgi")
get_example("/solar_api/v1/GetLoggerLEDInfo.cgi")
get_example("/solar_api/v1/GetMeterRealtimeData.cgi?Scope=System")
get_example("/solar_api/v1/GetPowerFlowRealtimeData.fcgi")
get_example("/solar_api/v1/GetStorageRealtimeData.cgi?Scope=System")

"""

import collections
import requests
import argparse
import sys 


INVERTER_IP = "192.168.178.101"

data = collections.OrderedDict()

def get_data(url):
	try:
		r = requests.get(url, timeout=10)
		r.raise_for_status()
		return r.json()	
	except requests.exceptions.Timeout:
		print("Timeout requesting {} at {}".format(url, current_time_string))
	except requests.exceptions.RequestException as e:
		print("requests exception {} at {}".format(e, current_time_string))

	# if we get no data, we exit directly
	return exit()


def main(argv):
	powerflow_url = "http://" + INVERTER_IP + "/solar_api/v1/GetPowerFlowRealtimeData.fcgi"
	powerflow_data = get_data(powerflow_url)

	print("Left Side Raw Power Generation of Panels : ", powerflow_data['Body']['Data']['Site']['P_PV'] )
	print("Total current Home consumption is : ",powerflow_data['Body']['Data']['Site']['P_Load'])
	print("Powerfromgrid (-) /To Grid (+) is : ",powerflow_data['Body']['Data']['Site']['P_Grid'])
	print("BatteryCharge (-) / Discharge(+) is : ",powerflow_data['Body']['Data']['Site']['P_Akku'])

	battery_url = "http://" + INVERTER_IP + "/solar_api/v1/GetStorageRealtimeData.cgi?Scope=System"
	battery_data = get_data(battery_url)
	 
	print("Battery charge percent : ", battery_data['Body']['Data']['0']['Controller']['StateOfCharge_Relative'])


	print("##+PV## ", int(powerflow_data['Body']['Data']['Site']['P_PV']))
	print("##+HOME## ", -1 * int(powerflow_data['Body']['Data']['Site']['P_Load']))
	print("##+GRID## ", -1 * int(powerflow_data['Body']['Data']['Site']['P_Grid']))
	print("##-BATTERYCHARGE## ", int(powerflow_data['Body']['Data']['Site']['P_Akku']))
	print("##+BATTERYCARGEPERCENT## ", int(battery_data['Body']['Data']['0']['Controller']['StateOfCharge_Relative']))


if __name__ == "__main__":
	CommandlineInput=0

	my_parser = argparse.ArgumentParser()
	my_parser.add_argument('--host', type=str)

	args = vars(my_parser.parse_args())
	for i in args:
		if (str(args[i]) != 'None'):
			print ("Found", i , args[i])
			CommandlineInput = 1
			print ("CommandlineInput is ", CommandlineInput , " So will obeye what was specified on the commandline")

	if(CommandlineInput == 1):
		print ("Now Setting Parameters :")
		if (str(args['host']) != ''):
			print ("Setting host : ",args['host'] )
			INVERTER_IP=args['host']


	main(sys.argv)
