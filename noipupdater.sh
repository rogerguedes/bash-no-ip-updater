#!/bin/bash

# No-IP uses your email address for the username. Both the username and password
# must be URL encoded. URL encoder: http://meyerweb.com/eric/tools/dencoder/
USERNAME=username
PASSWORD=password
# Multiple hosts associated with a single IP address can be entered by
# separating them with commas. Expample: HOST=host1.domain.org,host2.domain.org
HOST=hostsite
LOGFILE=logdir/noip.log
STOREDIPFILE=configdir/current_ip
USERAGENT="Simple Bash No-IP Updater/0.4 antoniocs@gmail.com"

if [ ! -e $STOREDIPFILE ]; then
	touch $STOREDIPFILE
fi

NEWIP=$(wget -O - http://icanhazip.com/ -o /dev/null)
STOREDIP=$(cat $STOREDIPFILE)

if [ "$NEWIP" != "$STOREDIP" ]; then
	RESULT=$(wget -O - -q --user-agent="$USERAGENT" --no-check-certificate "https://$USERNAME:$PASSWORD@dynupdate.no-ip.com/nic/update?hostname=$HOST&myip=$NEWIP")

	LOGLINE="[$(date +"%Y-%m-%d %H:%M:%S")] $RESULT"
	echo $NEWIP > $STOREDIPFILE
else
	LOGLINE="[$(date +"%Y-%m-%d %H:%M:%S")] No IP change"
fi

echo $LOGLINE >> $LOGFILE

exit 0

