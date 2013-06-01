#!/bin/bash

# Defines

USERAGENT="Bash No-IP Updater/0.6 mowerm@gmail.com"

if [ -e './config' ]; then
    source ./config
else
    echo "Config file not found."
    exit 1
fi

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
   echo "USERNAME or PASSWORD has not been set in the config file."
   exit 1
fi

USERNAME=$(echo -ne $USERNAME | xxd -plain | tr -d '\n' | sed 's/\(..\)/%\1/g')
PASSWORD=$(echo -ne $PASSWORD | xxd -plain | tr -d '\n' | sed 's/\(..\)/%\1/g')

if ! [[ "$FORCEUPDATEFREQ" =~ ^[0-9]+$ ]] ; then
   echo "FORCEUPDATEFREQ has not been set correctly in the config file"
   exit 1
fi

if [ ! -d $LOGDIR ]; then
    mkdir -p $LOGDIR
    if [ $? -ne 0 ]; then
        echo "Log directory could not be created or accessed."
        exit 1
    fi
fi

LOGFILE=${LOGDIR%/}/noip.log
IPFILE=${LOGDIR%/}/last_ip
if [ ! -e $LOGFILE ] || [ ! -e $IPFILE ]; then
	touch $LOGFILE $IPFILE
    if [ $? -ne 0 ]; then
        echo "Log files could not be created. Is the log directory writable?"
        exit 1
    fi
elif [ ! -w $LOGFILE ] || [ ! -w $IPFILE ]; then
    echo "Log files not writable."
    exit 1
fi
STOREDIP=$(cat $IPFILE)

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
	echo $NEWIP > $IPFILE
elif [ "$NEWIP" != "$STOREDIP" ]; then
	RESULT=$(curl -s -k --user-agent "$USERAGENT" "https://$USERNAME:$PASSWORD@dynupdate.no-ip.com/nic/update?hostname=$HOST&myip=$NEWIP")

	LOGLINE="[$(date +'%Y-%m-%d %H:%M:%S')] $RESULT"
	echo $NEWIP > $IPFILE
else
	LOGLINE="[$(date +'%Y-%m-%d %H:%M:%S')] No IP change"
fi

echo $LOGLINE >> $LOGFILE

exit 0

