Properly handle multiple hostname updates:
Example: good 111.111.111.111 nohost

1.  separeate log line for each host update - write hostname in line
2.  force update needs to check each host for force-update status

For cron, echoed statements should be directed to error stream.
