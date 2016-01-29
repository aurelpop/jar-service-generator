#!/bin/bash

function displaySuccessMessage {
	local message=$1
	echo -e "\e[32m$message\e[0m"
}

function displayErrorMessage {
	local message=$1
	echo -e "\e[31m$message\e[0m"
}

function validateParameterSet {
	#Initialize parameters
	local parameterName="$1"

	if [[ -z $parameterName ]]; then
		usage
	fi	
}

function getOptionValue {
	#Initialize parameters
	local option="$1"
	local optionName="--$2="
	
	#Extract value
	echo $(echo $option|cut -c $(echo $optionName|wc -c)-)
}

# Makes the file writable by the group $serviceGroup.
function makeFileWritable {
	#Initialize parameters
	local fileName="$1"
	local group="$2"

	touch $fileName || return 1
	chgrp $group $fileName || return 1
	chmod g+w $fileName || return 1

	return 0;
}

# Returns 0 if the process with PID $1 is running.
function checkProcessIsRunning {
	#Initialize parameters
	local pid="$1"

	if [ -z "$pid" -o "$pid" == " " ]; then return 1; fi
	if [ ! -e /proc/$pid ]; then return 1; fi

	return 0; 
}
