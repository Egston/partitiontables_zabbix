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

function MySQL() {
    mysql \
        -u"$(GetConf DBUser zabbix)" \
        -p"$(GetConf DBPassword)" \
        -P"$(GetConf DBPort 3306)" \
        -h"$(GetConf DBHost 127.0.0.1)" \
          "$(GetConf DBName zabbix)" \
        -e "$@" && return
    echo "..FAILED: $@" 1>&2
}

function table_contains() {
    local TABLE_NAME="$1" MASK="$2"
    MySQL "show create table $TABLE_NAME" | grep -q "$MASK"
}

function create_partition() {
    local TABLE_NAME="$1" PARTITION_NAME="$2" TIME_PARTITIONS="$3"

    if table_contains "$TABLE_NAME" "PARTITION BY RANGE"
    then
        table_contains "$TABLE_NAME" "p${PARTITION_NAME}" && return

        printf "table %-12s create partition p${PARTITION_NAME}\n" ${TABLE_NAME}
        MySQL "ALTER TABLE ${TABLE_NAME}  ADD PARTITION (PARTITION p${PARTITION_NAME} VALUES LESS THAN (${TIME_PARTITIONS}))"
    else
        printf "table %-12s create partition p${PARTITION_NAME}\n" ${TABLE_NAME}
        MySQL "ALTER TABLE $TABLE_NAME PARTITION BY RANGE( clock ) (PARTITION p${PARTITION_NAME}  VALUES LESS THAN (${TIME_PARTITIONS}))"
    fi
}

function drop_partition() {
    local TABLE_NAME="$1" PARTITION_NAME="$2"

    table_contains "$TABLE_NAME" "p${PARTITION_NAME}" || return 0

    printf "table %-12s drop partition p${PARTITION_NAME}\n" ${TABLE_NAME}
    MySQL "ALTER TABLE ${TABLE_NAME} DROP PARTITION p${PARTITION_NAME}"
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

function drop_partitions_history() {
    for TABLE in ${HISTORY_TABLE}; do
        drop_partition "$TABLE" "$(date +"%Y%m%d" --date="${HISTORY_DAYS} days ago")"
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

function drop_partitions_trend() {
    for TABLE in ${TREND_TABLE}; do
        drop_partition "$TABLE" "$(date +"%Y%m" --date="${TREND_MONTHS} months ago")"
    done
}

function main() {
    create_partitions_history
    create_partitions_trend
    drop_partitions_history
    drop_partitions_trend
}

#main
