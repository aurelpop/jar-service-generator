#!/bin/bash

. util.sh

function usage {
	echo "Usage: $0 {install|uninstall} [--serviceName=VALUE] [--serviceGroup=VALUE] [--jarPath=VALUE] [--javaOptions=VALUE]"
	exit 1
}

function install {
	#Initialize parameters
	local jarPath="$1"
	local serviceName="$2"
	local serviceGroup="$3"
	local jarParameters="$4"
	local javaOptions="$5"

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
		chown $user:$user -R $serviceHomeDirectory
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
	template="${template/\%JAR_PARAMETERS\%/$jarParameters}"
	template="${template/\%JAVA_OPTIONS\%/$javaOptions}"
	template="${template/\%JAR_PATH\%/$jarPath}"
	template="${template/\%UTIL_SCRIPTS\%/$utilFunctions}"

	echo "$template" > /etc/init.d/$serviceName
	chmod +x /etc/init.d/$serviceName
	
	update-rc.d $serviceName defaults 3 5 >/dev/null 2>&1

	echo $serviceName installed.
	echo You may now use $serviceName to call this script.
	return 0;
}

function main {
	#Initialize parameters
	local action="$1"
	local serviceName="$2"
	local serviceGroup="$3"
	local jarPath="$4"
	local jarParameters="$5"
	local javaOptions="$6"

	case "$action" in
		install)
			#Check that the required options are set
			validateParameterSet $jarPath
			validateParameterSet $serviceName
			validateParameterSet $serviceGroup	
	
			install $jarPath $serviceName $serviceGroup $jarParameters $javaOptions
		;;
		uninstall)
			#Check that the required options are set
			validateParameterSet $serviceName

			uninstall $serviceName
		;;
		check)
			#Check that the required options are set
			validateParameterSet $serviceName

			checkServiceExists $serviceName
		;;
		*)
		 	usage
		 ;;
      	esac
	return 0;
}

#Initialize options variable
for option in "$@"; do options=$(addOption "$options" $option); done
options=$(addOption "$options" "action" $1)


#Initialize options
action=$(getOption "$options" "action")
jarPath=$(getOption "$options" "jarPath")
jarParameters=$(getOption "$options" "jarParameters")
javaOptions=$(getOption "$options" "javaOptions")
serviceName=$(getOption "$options" "serviceName")
serviceGroup=$(getOption "$options" "serviceGroup")

#Run
main $action $serviceName $serviceGroup $jarPath $jarParameters $javaOptions


