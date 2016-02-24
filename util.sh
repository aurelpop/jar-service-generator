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

	if [[ $parameterName == "null" ]]; then
		usage
	fi	
}

# Get option by name from a string of options formatted as XML (E.g: <option>--a=b</option><option>--c=d</option>
function getOption {
	local options="$1"
	local optionName="$2"

	echo "" | awk -v name="$optionName" -v options="$options" '
		{ 
			regex="<option>--"name"=([^<]*)<\\/option>";
			resultIndex = match(options, regex, results);
			if(resultIndex == 0) {
				print "null";
			} else {
				print results[1];
			}
		}
	';
}

# Add new option (name or name and value)
function addOption {
	local options="$1"
	local name="$2"
	local value="$3"

	if [[ -z $value ]]; then
		echo $options"<option>"$name"</option>"
	else
		echo $options"<option>--"$name"="$value"</option>"
	fi;
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

# Uninstall service by name
function uninstall {
	#Initialize parameters
	local serviceName="$1"
	
	#Initialize data
	local user="$serviceName"
	local userGroups=$(groups $serviceName|cut -c $(echo "$serviceName : "|wc -c)-)
	local serviceGroup=$(echo $userGroups|cut -d' ' -f 1)
	local userHomeDirectory=$(eval echo ~$user)
	
	#Remove user
	echo -n "Removing user $user: "
	userdel $user >/dev/null 2>&1
	local code=$?
	if [ $code -eq 0 ]; then
		displaySuccessMessage "Done"
	elif [ $code -eq 6 ]; then
		displayErrorMessage "User doesn't exist"
	else
		displayErrorMessage "Failed"	
	fi

	chown root:root -R $userHomeDirectory

	#Remove group
	echo -n "Removing group $serviceGroup: "
	groupdel $serviceGroup
	if [ $? -ne 0 ]; then
		displayErrorMessage "Failed (Possible reason: Permission Denied)"
	else
		displaySuccessMessage "Done"
	fi

	#Remove script from /etc/rc.init
	echo -n "Removing service file: "
	rm -rf /etc/init.d/$serviceName
	displaySuccessMessage "Done"

	#Unregister service
	echo -n "Disabling service: "
	update-rc.d $serviceName remove >/dev/null 2>&1
	displaySuccessMessage "Done"
}

# Check if a service exists
function checkServiceExists {
	#Initialize parameters
	local serviceName="$1"
	
	if [ -f "/etc/init.d/$serviceName" ]; then
	    exit 0
	else
	    exit 2
	fi
}
