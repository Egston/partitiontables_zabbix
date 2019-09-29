#!/bin/bash
# author: itnihao
# mail: itnihao#qq.com
# Apache License Version 2.0
# date: 2018-06-06
# funtion: create parition for zabbix MySQL 
# repo: https://github.com/zabbix-book/partitiontables_zabbix

ZABBIX_CONF="/etc/zabbix/zabbix_server.conf"

HISTORY_DAYS=30
TREND_MONTHS=12

HISTORY_TABLE="history history_log history_str history_text history_uint"
TREND_TABLE="trends trends_uint"

function GetConf() {
    local RESULT="$(awk -F= '$1 == "'"$1"'" { print $2; exit }' "$ZABBIX_CONF")"
    echo "${RESULT:-$2}"
}

function MySQL_base() {
    mysql -u"$(GetConf DBUser zabbix)" \
          -p"$(GetConf DBPassword)" \
          -P"$(GetConf DBPort 3306)" \
          -h"$(GetConf DBHost 127.0.0.1)" \
            "$(GetConf DBName zabbix)" \
          -e "$@"
}

function MySQL() {
    echo "EXEC: $@" 1>&2
    MySQL_base "$@"
}

function table_contains() {
    local TABLE="$1" MASK="$2"
    MySQL_base "show create table $TABLE" | grep -q "$MASK"
}

function create_partition() {
    local TABLE="$1" PART="$2" TIME="$3"

    if table_contains "$TABLE" "PARTITION BY RANGE"
    then
        table_contains "$TABLE" "p${PART}" && return
        MySQL "ALTER TABLE $TABLE ADD PARTITION (PARTITION p${PART} VALUES LESS THAN (${TIME}))"
    else
        MySQL "ALTER TABLE $TABLE PARTITION BY RANGE( clock ) (PARTITION p${PART}  VALUES LESS THAN (${TIME}))"
    fi
}

function drop_partition() {
    local TABLE="$1" PART="$2"
    table_contains "$TABLE" "p${PART}" || return
    MySQL "ALTER TABLE ${TABLE} DROP PARTITION p${PART}"
}

function create_partitions_history() {
    for DAY in 0 1 2 3 4 5 6 7; do
        PART="$(date +"%Y%m%d" --date="$DAY days")"
        TIME="$(date -d "${PART} 23:59:59" +%s)"
        for TABLE in ${HISTORY_TABLE}; do
            create_partition "$TABLE" "$PART" "$TIME"
        done
    done
}

function create_partitions_trend() {
    for MONTH in 0 1 2 3 4 5; do
        PART="$(date +"%Y%m" --date="$MONTH months")"
        TIME="$(date -d "${PART}01 00:00:00" +%s)"
        for TABLE in ${TREND_TABLE}; do
            create_partition "$TABLE" "$PART" "$TIME"
        done
    done
}

create_partitions_history
create_partitions_trend

# Drop partitions:
for TABLE in ${HISTORY_TABLE}; do drop_partition "$TABLE" "$(date +"%Y%m%d" --date="${HISTORY_DAYS} days ago")"  ; done
for TABLE in ${TREND_TABLE}  ; do drop_partition "$TABLE" "$(date +"%Y%m"   --date="${TREND_MONTHS} months ago")"; done

## END ##
