#!/bin/bash

function help()
{
    echo "usage: safe-bgsave -t THRESHOLD -i INTERVAL -p PORT."
    echo "       safe-bgsave -t 20        -i 1        -p 7002"
    exit
}

# success return 0; fail return 1.
function safe_bgsave()
{
    # check security
    local available=`free -g | grep Mem | awk '{print $7}'`
    if [ ${available} -le ${THRESHOLD} ]
    then
        echo `date` " Available memory: ${available} <= threshold: ${THRESHOLD}. Do not process bgsave." >> ${LOG_PATH} 2>&1
        return 1
    fi

    # bgsave
    local bgsave=`${REDIS_CLI} -p ${PORT} bgsave`
    echo `date` " ${bgsave}." >> ${LOG_PATH} 2>&1

    sleep ${INTERVAL}

    local pid=`ps -ef | grep "${PROCESS_NAME}" | grep -v grep | awk '{print $2}'`
    while [ -n "${pid}" ]
    do
        available=`free -g | grep Mem | awk '{print $7}'`

        if [ ${available} -le ${THRESHOLD} ]
        then
            echo `date` " bgsave failed. Available memory: ${available} <= threshold: ${THRESHOLD}. Trying to kill process." >> ${LOG_PATH} 2>&1
            kill "${pid}"
            return 1
        fi

        sleep ${INTERVAL}

        pid=`ps -ef | grep "${PROCESS_NAME}" | grep -v grep | awk '{print $2}'`
    done

    echo `date` " bgsave success." >> ${LOG_PATH} 2>&1
    return 0
}

# Begin
[ $# -ne 6 ] && help

while [ -n "$1" ]
do
    case "$1" in
        -t) THRESHOLD=$2
            shift 2
            ;;
        -i) INTERVAL=$2
            shift 2
            ;;
        -p) PORT=$2
            shift 2
            ;;
         *) help
            ;;
    esac
done

REDIS_CLI="redis-cli"
PROCESS_NAME="redis-rdb-bgsave"
LOG_PATH="/opt/data/redis/safe_bgsave.${PORT}.log"

safe_bgsave

if [ $? -eq 1 ]
then
    exit 1
fi

exit 0
