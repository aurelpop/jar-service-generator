#!/bin/bash
### BEGIN INIT INFO
# Provides:                   %SERVICE_NAME%
# Required-Start:             $network $local_fs $remote_fs
# X-UnitedLinux-Should-Start: $named sendmail
# Required-Stop:              $network $local_fs $remote_fs
# X-UnitedLinux-Should-Stop:  $named sendmail
# Default-Start:              3 5
# Default-Stop:               0 1 2 6
# Short-Description:          Java Daemon
# Description:                A Java daemon
### END INIT INFO

%UTIL_SCRIPTS%

function checkProcessIsOurService {
	local pid="$1"
	local cmd="$(ps -p $pid --no-headers -o comm)"

	if [ "$cmd" != "$javaCommand" -a "$cmd" != "$javaCommand.bin" ]; then return 1; fi
	grep -q --binary -F "$serviceName" /proc/$pid/cmdline
	if [ $? -ne 0 ]; then return 1; fi

	return 0;
}

function getServicePid {
	if [ ! -f $pidFile ]; then return 1; fi

	servicePid="$(<$pidFile)"
	checkProcessIsRunning $servicePid || return 1
	checkProcessIsOurService $servicePid || return 1

	return 0;
}

function startServiceProcess {
	rm -f $pidFile

	makeFileWritable $pidFile $serviceGroup || return 1
	makeFileWritable $serviceLogFile $serviceGroup || return 1

	local cmd="setsid $javaCommandLine >>$serviceLogFile 2>&1 & echo \$! >$pidFile"
	su $serviceUser $SHELL -c "$cmd" || return 1
	sleep 0.1

	servicePid="$(<$pidFile)"
	if checkProcessIsRunning $servicePid; then :; 
	else
		displayErrorMessage "\n$serviceName start failed, see logfile."
		return 1
	fi

	return 0;
}

function stopServiceProcess {
	kill $servicePid || return 1

	for ((i=0; i<maxShutdownTime*10; i++)); do
		checkProcessIsRunning $servicePid
		if [ $? -ne 0 ]; then
			rm -f $pidFile
			return 0
		fi

		sleep 0.1
	done

	displayErrorMessage "$serviceName did not terminate within $maxShutdownTime seconds, sending SIGKILL..."
	kill -s KILL $servicePid || return 1

	local killWaitTime=15
	for ((i=0; i<killWaitTime*10; i++)); do
		checkProcessIsRunning $servicePid
		if [ $? -ne 0 ]; then
			rm -f $pidFile
			return 0
		fi

		sleep 0.1
	done

	displayErrorMessage "Error: $serviceName could not be stopped within $maxShutdownTime+$killWaitTime seconds!"
	return 1;
}

function startService {
	getServicePid
	if [ $? -eq 0 ];
	then 
		echo "$serviceName is already running";
		return 0;
	fi

	echo "Starting $serviceName   "
	startServiceProcess
	if [ $? -ne 0 ]; then return 1; fi

	return 0;
}

function stopService {
	getServicePid
	if [ $? -ne 0 ];
	then
		echo "$serviceName is not running";
		return 0;
	fi

	echo "Stopping $serviceName   "
	stopServiceProcess
	if [ $? -ne 0 ]; then return 1; fi

	return 0;
}

function checkServiceStatus {
	echo -n "Checking for $serviceName:   "
	if getServicePid; then
		displaySuccessMessage "ON"
		exit 0
	else
		displayErrorMessage "OFF"
		exit 3
	fi
 }

function main {
	action="$1"
	case "$action" in
		start)
			startService
		;;
		stop)
			stopService
		;;
		restart)
			stopService && startService
		;;
		status)
			checkServiceStatus
		;;
		uninstall)
			uninstall $serviceName
		;;
		*)
			displayErrorMessage "Usage: $0 {start|stop|restart|status}"
			exit 1
		;;
	esac
	return 0; 
}

#Initialize data
serviceName=%SERVICE_NAME%
serviceName=${serviceName,}

serviceUser=%USER%
serviceGroup=%GROUP%

serviceLogFile="/var/log/$serviceName.log"
pidFile="/var/run/$serviceName.pid"

javaCommand="java"
maxShutdownTime=15
javaCommandLine="$javaCommand %JAVA_OPTIONS% -jar %JAR_PATH% %JAR_PARAMETERS%"

main $1
