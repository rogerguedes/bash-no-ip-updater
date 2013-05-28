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
# Force script to update No-IP after a number of days have passed. This helps
# prevent hostname expiration. Enter the value in seconds: 864000 = 10days
# Setting FORCEUPDATEFREQ=0 will disable this feature
FORCEUPDATEFREQ=864000
USERAGENT="Simple Bash No-IP Updater/0.4 antoniocs@gmail.com"

# Check log for last successful ip change to No-IP and set FUPD flag if an
# update is necessary.  (Note: 'nochg' return code is not enough for No-IP to be
# satisfied; must be 'good' return code)
FUPD=false
TODAY=$(date '+%s')
if [ $FORCEUPDATEFREQ -eq 0 ]; then
    FUPD=false
elif [ -e $LOGFILE ] && tac $LOGFILE | grep -q -m1 'good'; then
    LASTGC=$(tac $LOGFILE | grep -m1 'good')
    Y1=$(echo $LASTGC | cut -c 2- | cut -d "-" -f 1)
    M1=$(echo $LASTGC | cut -c 2- | cut -d "-" -f 2)
    D1=$(echo $LASTGC | cut -c 2- | cut -d "-" -f 3 | cut -d " " -f 1)
    LASTCONTACT=$(date -d "$Y1-$M1-$D1" '+%s')
    if [ `expr $TODAY - $LASTCONTACT` -gt $FORCEUPDATEFREQ ]; then
        FUPD=true
    fi
else
    FUPD=true
fi

if [ ! -e $STOREDIPFILE ]; then
	touch $STOREDIPFILE
fi

NEWIP=$(wget -O - -o /dev/null http://icanhazip.com)
STOREDIP=$(cat $STOREDIPFILE)

if [ $FUPD == true ]; then
    wget -q -o /dev/null --user-agent="$USERAGENT" --no-check-certificate "https://$USERNAME:$PASSWORD@dynupdate.no-ip.com/nic/update?hostname=$HOST&myip=127.0.0.1"
    sleep 5
    RESULT=$(wget -O - -o /dev/null --user-agent="$USERAGENT" --no-check-certificate "https://$USERNAME:$PASSWORD@dynupdate.no-ip.com/nic/update?hostname=$HOST&myip=$NEWIP")

    LOGLINE="[$(date +"%Y-%m-%d %H:%M:%S")] $RESULT"
	echo $NEWIP > $STOREDIPFILE
elif [ "$NEWIP" != "$STOREDIP" ]; then
	RESULT=$(wget -O - -o /dev/null --user-agent="$USERAGENT" --no-check-certificate "https://$USERNAME:$PASSWORD@dynupdate.no-ip.com/nic/update?hostname=$HOST&myip=$NEWIP")

	LOGLINE="[$(date +"%Y-%m-%d %H:%M:%S")] $RESULT"
	echo $NEWIP > $STOREDIPFILE
else
	LOGLINE="[$(date +"%Y-%m-%d %H:%M:%S")] No IP change"
fi

echo $LOGLINE >> $LOGFILE

exit 0

