#!/bin/bash

# Monitors a log file for specific entries, performs actions, and outputs to log file

tail -Fn0 /ArcSightSmartConnectors/current/logs/agent.out.wrapper.log | \
while read line ; do
		echo "$line" | grep -q "ET="
		
		if [[ $line =~ "ET=Down" ]];	then
			echo "$(date)  Forwarding Connector Is Down" >> /var/log/connector_monitor.log
			/etc/init.d/arc_superagent_ng_Name restart
			echo "$(date) Restarting  Connector" >> /var/log/connector_monitor.log
			
		elif [[ $line =~ "ET=Up" ]]; 	then
			echo "$(date) Forwarding Connector is Up" >> /var/log/connector_monitor.log
		fi
		
done
