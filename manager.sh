#!/bin/bash

. util.sh

function usage {
	echo "Usage: $0 {install|uninstall} [--serviceName=VALUE] [--serviceGroup=VALUE] [--jarPath=VALUE]"
	exit 1
}

function install {
	#Initialize parameters
	local jarPath="$1"
	local serviceName="$2"
	local serviceGroup="$3"

	#Initialize data
	local user="$serviceName"
	local serviceHomeDirectory=$(dirname $jarPath)

	#Create group if doesn't exist
	getent group $serviceGroup  >/dev/null 2>&1
	local code=$?
	echo -n "Creating group $serviceGroup: "
   	if [ $code -ne 0 ]; then
      		groupadd -r $serviceGroup
		if [ $? -ne 0 ]; then
			displayErrorMessage "Failed (Possible reason: Permission Denied)"
		else
			displaySuccessMessage "Done"
		fi
	else
		displaySuccessMessage "Already Exists"
      	fi

	#Create user if doesn't exist
	id -u $user >/dev/null 2>&1
	local code=$?
	echo -n "Creating user $user: "
	if [ $code -ne 0 ]; then
		useradd -r -c "user for $serviceName service" -g $serviceGroup -d $serviceHomeDirectory $user
		displaySuccessMessage "Done"
	else
		displaySuccessMessage "Already exists"
	fi

	local utilFunctions=$(<util.sh)
	utilFunctions="${utilFunctions/\#\!\/bin\/bash/}"

	local template=$(<template.sh)
	template="${template/\%SERVICE_NAME\%/$serviceName}"
	template="${template/\%SERVICE_NAME\%/$serviceName}"
	template="${template/\%USER\%/$serviceName}"
	template="${template/\%GROUP\%/$serviceName}"
	template="${template/\%JAR_PATH\%/$jarPath}"
	template="${template/\%UTIL_SCRIPTS\%/$utilFunctions}"

	echo "$template" > /etc/init.d/$serviceName
	chmod +x /etc/init.d/$serviceName
	
	update-rc.d $serviceName defaults 3 5 >/dev/null 2>&1

	echo $serviceName installed.
	echo You may now use $serviceName to call this script.
	return 0;
}

function uninstall {
	#Initialize parameters
	local serviceName="$1"
	
	#Initialize data
	local user="$serviceName"
	local userGroups=$(groups $serviceName|cut -c $(echo "$serviceName : "|wc -c)-)
	local serviceGroup=$(echo $userGroups|cut -d' ' -f 1)
	
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

function main {
	local action="$1"
	local serviceName="$2"
	local serviceGroup="$3"
	local jarPath="$4"

	case "$action" in
		install)
			validateParameterSet $jarPath
			validateParameterSet $serviceName
			validateParameterSet $serviceGroup		
			install $jarPath $serviceName $serviceGroup
		;;
		uninstall)
			validateParameterSet $serviceName
			uninstall $serviceName
		;;
		*)
		 	usage
		 ;;
      	esac
	return 0;
}

#Initialize parameters
actionOption="$1"
serviceNameOption="$2"
serviceGroupOption="$3"
jarPathOption="$4"

#Initialize data
jarPath=$(getOptionValue $jarPathOption "jarPath")
serviceName=$(getOptionValue $serviceNameOption "serviceName")
serviceGroup=$(getOptionValue $serviceGroup "serviceGroup")

#Run
main $actionOption $serviceName $serviceGroup $jarPath 


