#!/bin/bash

# Defines

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
USERAGENT="Bash No-IP Updater/0.5 mowerm@gmail.com"

# Functions

# IP Validator
# http://www.linuxjournal.com/content/validating-ip-address-bash-script
function valid_ip() {
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

# Program

# Check log for last successful ip change to No-IP and set FUPD flag if an
# update is necessary.  (Note: 'nochg' return code is not enough for No-IP to be
# satisfied; must be 'good' return code)
FUPD=false
NOW=$(date '+%s')
if [ $FORCEUPDATEFREQ -eq 0 ]; then
    FUPD=false
elif [ -e $LOGFILE ] && tac $LOGFILE | grep -q -m1 'good'; then
    GOODLINE=$(tac $LOGFILE | grep -m1 'good')
    LASTGC=$([[ $GOODLINE =~ \[(.*?)\] ]] && echo "${BASH_REMATCH[1]}")
    LASTCONTACT=$(date -d "$LASTGC" '+%s')
    if [ `expr $NOW - $LASTCONTACT` -gt $FORCEUPDATEFREQ ]; then
        FUPD=true
    fi
else
    FUPD=true
fi

if [ ! -e $STOREDIPFILE ]; then
	touch $STOREDIPFILE
fi
STOREDIP=$(cat $STOREDIPFILE)

COUNTER=1
while ! valid_ip $NEWIP; do
    case $COUNTER in
        1)
            NEWIP=$(curl -s http://icanhazip.com | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}')
            let COUNTER++
            ;;
        2)
            NEWIP=$(curl -s http://checkip.dyndns.org | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}')
            let COUNTER++
            ;;
        3)
            NEWIP=$(curl -s http://wtfismyip.com/text | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}')
            let COUNTER++
            ;;
        4)
            NEWIP=$(curl -s http://www.networksecuritytoolkit.org/nst/tools/ip.php | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}')
            let COUNTER++
            ;;
        *)
            LOGLINE="[$(date +'%Y-%m-%d %H:%M:%S')] Could not find current IP"
            echo $LOGLINE >> $LOGFILE
            exit 1
            ;;
    esac
done

if [ $FUPD == true ]; then
    curl -s -k --user-agent "$USERAGENT" "https://$USERNAME:$PASSWORD@dynupdate.no-ip.com/nic/update?hostname=$HOST&myip=127.0.0.1" &> /dev/null
    sleep 5
    RESULT=$(curl -s -k --user-agent "$USERAGENT" "https://$USERNAME:$PASSWORD@dynupdate.no-ip.com/nic/update?hostname=$HOST&myip=$NEWIP")

    LOGLINE="[$(date +'%Y-%m-%d %H:%M:%S')] $RESULT"
	echo $NEWIP > $STOREDIPFILE
elif [ "$NEWIP" != "$STOREDIP" ]; then
	RESULT=$(curl -s -k --user-agent "$USERAGENT" "https://$USERNAME:$PASSWORD@dynupdate.no-ip.com/nic/update?hostname=$HOST&myip=$NEWIP")

	LOGLINE="[$(date +'%Y-%m-%d %H:%M:%S')] $RESULT"
	echo $NEWIP > $STOREDIPFILE
else
	LOGLINE="[$(date +'%Y-%m-%d %H:%M:%S')] No IP change"
fi

echo $LOGLINE >> $LOGFILE

exit 0

