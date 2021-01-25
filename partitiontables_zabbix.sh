#!/bin/bash

# Create/update partitioning for Zabbix MySQL 
# Based on https://github.com/zabbix-book/partitiontables_zabbix by itnihao#qq.com
# (Re)Written by ilya.evseev@gmail at Sep-2019
# Distributed under terms of Apache License Version 2.0
# Should be called daily from /etc/cron.d/xx like following:
# 1 0 * * * zabbix bash /path/to/partitiontables_zabbix.sh

set -e

ZABBIX_CONF="/etc/zabbix/zabbix_server.conf"

HISTORY_DAYS=${HISTORY_DAYS:-30}
TREND_MONTHS=${TREND_MONTHS:-12}

HISTORY_TABLE="history history_log history_str history_text history_uint"
TREND_TABLE="trends trends_uint"

function help() {
    cat <<- EOT
	Usage: $(basename $0) [--simulate] [init]

	  init	       create partitions for the whole storage period; this may
	                 be time consuming
	  --simulate   print SQL statements but do not execute them
	  --help|help  display this help and exit

	You can set following environmental variables in order to change the
	default	storage period:

	  HISTORY_DAYS - number of days of history to keep (defaults to 30)
	  TREND_MONTHS - number of months of trends to keep (defaults to 12)

	EOT
}

function GetConf() {
    local CONFIG_VAR="$1" DEFAULT_VALUE="$2"
    local RESULT="$(awk -F= '$1 == "'"$CONFIG_VAR"'" { print $2; exit }' "$ZABBIX_CONF")"
    echo "${RESULT:-$DEFAULT_VALUE}"
}

DBHOST="$(GetConf DBHost 127.0.0.1)"
DBPORT="$(GetConf DBPort 3306)"
DBUSER="$(GetConf DBUser zabbix)"
DBPASS="$(GetConf DBPassword)"
DBNAME="$(GetConf DBName zabbix)"

declare -i simulate=0
declare -i init=0
echo $* | grep -qw -- --simulate && simulate=1 || true
echo $* | grep -qw -- init && init=1 || true
echo $* | grep -qw -- help && { help; exit; } || true

function MySQL_base() {
    mysql -h"$DBHOST" -P"$DBPORT" -u"$DBUSER" -p"$DBPASS" "$DBNAME" -e "$@"
}

function MySQL() {
    echo "EXEC: $@" 1>&2
    if ((!simulate)); then
        MySQL_base "$@"
    fi
}

function table_contains() {
    local TABLE="$1" MASK="$2"
    MySQL_base "show create table $TABLE" | grep -q "$MASK"
}

function create_partition() {
    local TABLE="$1" PART="$2" TIME="$3"

    if table_contains "$TABLE" "PARTITION BY RANGE"
    then
        table_contains "$TABLE" "p${PART}" && return || true
        MySQL "ALTER TABLE $TABLE ADD PARTITION (PARTITION p${PART} VALUES LESS THAN (${TIME}))"
    else
        MySQL "ALTER TABLE $TABLE PARTITION BY RANGE( clock ) (PARTITION p${PART}  VALUES LESS THAN (${TIME}))"
    fi
}

function drop_partition() {
    local TABLE="$1" PART="$2"
    table_contains "$TABLE" "p${PART}" || return 0
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

function create_all_partitions_history() {
    for TABLE in ${HISTORY_TABLE}; do
        PART_SQL=
        for DAY in $(seq -$HISTORY_DAYS 7); do
            PART="$(date +"%Y%m%d" --date="$DAY days")"
            TIME="$(date -d "${PART} 23:59:59" +%s)"
            if [ -n "$PART_SQL" ]; then
                PART_SQL="$PART_SQL,"
            fi
            PART_SQL="$PART_SQL PARTITION p${PART} VALUES LESS THAN (${TIME})"
        done
        MySQL "ALTER TABLE $TABLE PARTITION BY RANGE( clock ) ($PART_SQL)"
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

function create_all_partitions_trend() {
    for TABLE in ${TREND_TABLE}; do
        PART_SQL=
        for MONTH in $(seq -$TREND_MONTHS 5); do
            PART="$(date +"%Y%m" --date="$MONTH months")"
            TIME="$(date -d "${PART}01 00:00:00" +%s)"
            if [ -n "$PART_SQL" ]; then
                PART_SQL="$PART_SQL,"
            fi
            PART_SQL="$PART_SQL PARTITION p${PART} VALUES LESS THAN (${TIME})"
        done
        MySQL "ALTER TABLE $TABLE PARTITION BY RANGE( clock ) ($PART_SQL)"
    done
}

if ((init)); then
    create_all_partitions_history
    create_all_partitions_trend
else
    create_partitions_history
    create_partitions_trend
fi

# Drop partitions:
for TABLE in ${HISTORY_TABLE}; do drop_partition "$TABLE" "$(date +"%Y%m%d" --date="${HISTORY_DAYS} days ago")"  ; done
for TABLE in ${TREND_TABLE}  ; do drop_partition "$TABLE" "$(date +"%Y%m"   --date="${TREND_MONTHS} months ago")"; done

exit 0
