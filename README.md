# partitiontables_zabbix

* Based on [work of itnihao#qq.com](https://github.com/zabbix-book/partitiontables_zabbix)

### Compatibility:

* Zabbix versions: 2.2, 3.0, 3.2, 3.4, 4.0
* MySQL  versions: 5.6, 5.7, 8.0 

### Configure:

* Database settings are loaded from /etc/zabbix/zabbix_server.conf
* Other defaults:
  * `HISTORY_DAYS=30`
  * `TREND_MONTHS=12`
* Check/fix all settings at the top of the [script](partitiontables_zabbix.sh).

### Running:

* crontab -e:
  ```
  1 0 * * * bash /path/to/partitiontables_zabbix.sh
  ```
* You can run it manually from command line too.

### Check:

* `show create table history_uint\G`
* `show create table trend_uint\G`
