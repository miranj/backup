#!/bin/sh
#==================================================================================================
#
#         FILE:  get-arguments.sh
#
#        USAGE:  get-arguments.sh [-c|--config=<path_to_config.json>] [-t|--test]
#
#  DESCRIPTION:  Captures command line named arugments.
# 
#==================================================================================================

for i in "$@"
do
case $i in
  -c=*|--config=*)
  BACKUP_CONFIG_FILE="${i#*=}"
  shift
  ;;
  -t|--test)
  BACKUP_TESTING=1
  shift
  ;;esac
done

if [ $BACKUP_TESTING ]
then
  echo BACKUP_CONFIG_FILE  = "${BACKUP_CONFIG_FILE}"
fi

