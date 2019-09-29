#!/bin/bash
# author: itnihao
# mail: itnihao#qq.com
# Apache License Version 2.0
# date: 2018-06-06
# funtion: create parition for zabbix MySQL 
# repo: https://github.com/zabbix-book/partitiontables_zabbix

ZABBIX_CONF="/etc/zabbix/zabbix_server.conf"
ZABBIX_USER="$(awk -F= '$1 == "DBUser"     { print $2; exit }' "$ZABBIX_CONF")"
 ZABBIX_PWD="$(awk -F= '$1 == "DBPassword" { print $2; exit }' "$ZABBIX_CONF")"
  ZABBIX_DB="$(awk -F= '$1 == "DBName"     { print $2; exit }' "$ZABBIX_CONF")"
ZABBIX_PORT="$(awk -F= '$1 == "DBPort"     { print $2; exit }' "$ZABBIX_CONF")"
ZABBIX_HOST="$(awk -F= '$1 == "DBHost"     { print $2; exit }' "$ZABBIX_CONF")"
MYSQL_BIN="mysql"

HISTORY_DAYS=30

TREND_MONTHS=12

HISTORY_TABLE="history history_log history_str history_text history_uint"
TREND_TABLE="trends trends_uint"

MYSQL_CMD=$(echo ${MYSQL_BIN} -u${ZABBIX_USER:-zabbix} -p${ZABBIX_PWD} -P${ZABBIX_PORT:-3306} -h${ZABBIX_HOST:-127.0.0.1} ${ZABBIX_DB:-zabbix})

function create_partitions_history() {
    for PARTITIONS_CREATE_EVERY_DAY in $(date +"%Y%m%d") $(date +"%Y%m%d" --date='1 days') $(date +"%Y%m%d" --date='2 days') $(date +"%Y%m%d" --date='3 days')  $(date +"%Y%m%d" --date='4 days') $(date +"%Y%m%d" --date='5 days') $(date +"%Y%m%d" --date='6 days') $(date +"%Y%m%d" --date='7 days')
    do
        TIME_PARTITIONS=$(date -d "$(echo ${PARTITIONS_CREATE_EVERY_DAY} 23:59:59)" +%s)
        for TABLE_NAME in ${HISTORY_TABLE}
        do
            SQL1=$(echo "show create table ${TABLE_NAME};")
            RET1=$(${MYSQL_CMD} -e "${SQL1}"|grep "PARTITION BY RANGE"|wc -l)
            if [ "${RET1}" == "0" ];then
                SQL2=$(echo "ALTER TABLE $TABLE_NAME PARTITION BY RANGE( clock ) (PARTITION p${PARTITIONS_CREATE_EVERY_DAY}  VALUES LESS THAN (${TIME_PARTITIONS}));")
                RET2=$(${MYSQL_CMD} -e "${SQL2}")
                if [ "${RET2}" != "" ];then
                    echo  ${RET2}
                    echo "${SQL2}"
                else
                    printf "table %-12s create partitions p${PARTITIONS_CREATE_EVERY_DAY}\n" ${TABLE_NAME}
                fi
                continue
            fi
            if [ "${RET1}" != "0" ];then
                SQL3=$(echo "show create table ${TABLE_NAME};")
                RET3=$(${MYSQL_CMD} -e "${SQL3}"|grep "p${PARTITIONS_CREATE_EVERY_DAY}"|wc -l)
                if [ "${RET3}" == "0" ];then
                    TIME_PARTITIONS=$(date -d "$(echo ${PARTITIONS_CREATE_EVERY_DAY} 23:59:59)" +%s) 
                    SQL4=$(echo "ALTER TABLE $TABLE_NAME  ADD PARTITION (PARTITION p${PARTITIONS_CREATE_EVERY_DAY} VALUES LESS THAN (${TIME_PARTITIONS}));")
                    RET4=$(${MYSQL_CMD} -e "${SQL4}")
                    if [ "${RET4}" != "" ];then
                        echo  ${RET4}
                        echo "${SQL4}"
                    else
                        printf "table %-12s create partitions p${PARTITIONS_CREATE_EVERY_DAY}\n" ${TABLE_NAME}
                    fi
                fi
            fi
        done
    done
}

function drop_partitions_history() {
    for PARTITIONS_DELETE_DAYS_AGO in $(date +"%Y%m%d" --date="${HISTORY_DAYS} days ago")
    do
        for TABLE_NAME in ${HISTORY_TABLE}
        do
            SQL=$(echo -e  "show create table ${TABLE_NAME};")
            RET=$(${MYSQL_CMD} -e "${SQL}"|grep "p${PARTITIONS_DELETE_DAYS_AGO}"|wc -l)
            if [ "${RET}" == "1" ];then
                SQL=$(echo "ALTER TABLE ${TABLE_NAME} DROP PARTITION p${PARTITIONS_DELETE_DAYS_AGO};")
                RET=$(${MYSQL_CMD} -e "${SQL}")
                if [ "${RET}" != "" ];then
                    echo  ${RET}
                    echo "${SQL}"
                else
                    printf "table %-12s drop partitions p${PARTITIONS_DELETE_DAYS_AGO}\n" ${TABLE_NAME}
                fi
            fi
        done
    done
}

function create_partitions_trend() {
    for PARTITIONS_CREATE_EVERY_MONTHS in $(date +"%Y%m") $(date +"%Y%m" --date='1 months') $(date +"%Y%m" --date='2 months') $(date +"%Y%m" --date='3 months') $(date +"%Y%m" --date='4 months') $(date +"%Y%m" --date='5 months')
    do
        TIME_PARTITIONS=$(date -d "$(echo ${PARTITIONS_CREATE_EVERY_MONTHS}01 00:00:00)" +%s)
        for TABLE_NAME in ${TREND_TABLE}
        do
            SQL1=$(echo "show create table ${TABLE_NAME};")
            RET1=$(${MYSQL_CMD} -e "${SQL1}"|grep "PARTITION BY RANGE"|wc -l)
            if [ "${RET1}" == "0" ];then
                SQL2=$(echo "ALTER TABLE $TABLE_NAME PARTITION BY RANGE( clock ) (PARTITION p${PARTITIONS_CREATE_EVERY_MONTHS}  VALUES LESS THAN (${TIME_PARTITIONS}));")
                RET2=$(${MYSQL_CMD} -e "${SQL2}")
                if [ "${RET2}" != "" ];then
                    echo  ${RET2}
                    echo "${SQL2}"
                else
                    printf "table %-12s create partitions p${PARTITIONS_CREATE_EVERY_MONTHS}\n" ${TABLE_NAME}
                fi
                continue
            fi
            if [ "${RET1}" != "0" ];then
                SQL3=$(echo "show create table ${TABLE_NAME};")
                RET3=$(${MYSQL_CMD} -e "${SQL3}"|grep "p${PARTITIONS_CREATE_EVERY_MONTHS}"|wc -l)
                if [ "${RET3}" == "0" ];then
                    SQL4=$(echo "ALTER TABLE ${TABLE_NAME}  ADD PARTITION (PARTITION p${PARTITIONS_CREATE_EVERY_MONTHS} VALUES LESS THAN (${TIME_PARTITIONS}));")
                    RET4=$(${MYSQL_CMD} -e "${SQL4}")
                    if [ "${RET4}" != "" ];then
                        echo  ${RET4}
                        echo "${SQL4}"
                    else
                        printf "table %-12s create partitions p${PARTITIONS_CREATE_EVERY_MONTHS}\n" ${TABLE_NAME}
                    fi
                fi
            fi
        done
    done
}

function drop_partitions_trend() {
    for PARTITIONS_DELETE_MONTHS_AGO in $(date +"%Y%m" --date="${TREND_MONTHS} months ago")
    do
        for TABLE_NAME in ${TREND_TABLE}
        do
            SQL=$(echo "show create table ${TABLE_NAME};")
            RET=$(${MYSQL_CMD} -e "${SQL}"|grep "p${PARTITIONS_DELETE_MONTHS_AGO}"|wc -l)
            if [ "${RET}" == "1" ];then
                SQL=$(echo "ALTER TABLE ${TABLE_NAME} DROP PARTITION p${PARTITIONS_DELETE_MONTHS_AGO};")
                RET=$(${MYSQL_CMD} -e "${SQL}")
                if [ "${RET}" != "" ];then
                    echo  ${RET}
                    echo "${SQL}"
                else
                    printf "table %-12s drop partitions p${PARTITIONS_DELETE_MONTHS_AGO}\n" ${TABLE_NAME}
                fi
            fi
        done
    done
}

function main() {
    create_partitions_history
    create_partitions_trend
    drop_partitions_history
    drop_partitions_trend
}

main
