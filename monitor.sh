#!/bin/bash

# Monitors a log file for specific entries and performs action.  

tail -Fn0 /ArcSightSmartConnectors/current/logs/agent.out.wrapper.log | \
while read line ; do
		echo "$line" | grep -q "ET="
		
		if [[ $line =~ "ET=Down" ]];	then
			echo "$(date)  Forwarding Connector Is Down"
			/etc/init.d/arc_superagent_ng_Name restart
			echo "$(date) Restarting  Connector"
			
		elif [[ $line =~ "ET=Up" ]]; 	then
			echo "$(date) Forwarding Connector is Up"
		fi
		
done
