#!/usr/bin/env roundup

describe "cleanup: Cleans up (deletes) aged project backups."

SCRIPT_BASE=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)
TEST_CONFIG_FILE=$SCRIPT_BASE/tests/config/backup-test.json
DIFF_EXCLUDE_PATTERNS_FILE=$SCRIPT_BASE/tests/config/exclude.txt
. $SCRIPT_BASE/config-helper.sh
BACKUP_CONFIG_FILE=$TEST_CONFIG_FILE
BACKUP_TESTING=1
. $SCRIPT_BASE/cleanup.sh

function get_file_age() {
  
  local backup_file=$1
  local timestamp=`echo $backup_file | rev | cut -d'-' -f1 | rev | cut -d'.' -f1`
  
  # http://stackoverflow.com/questions/8747845/how-can-i-detect-bsd-vs-gnu-version-of-date-in-shell-script
  if date --version >/dev/null 2>&1
  then
    timestamp=`date -d "${timestamp:0:8} ${timestamp:8:2}:${timestamp:10:2}:${timestamp:12:2}" +%s`
  else
    timestamp=`date -j -f "%Y%m%d%H%M%S" "$timestamp" "+%s"`
  fi
  
  # Return age of the file
  echo $((`date +%s` - $timestamp))
  
}

before() {
  
  # Set the Backup Config File and read Backup Root
  BACKUP_CONFIG_FILE=$TEST_CONFIG_FILE
  BACKUP_ROOT=$SCRIPT_BASE/`get_values $(get_key_regex root)`
  
  # Create + clean working folders
  [ -d $BACKUP_ROOT ]   && rm -r $BACKUP_ROOT
  [ -d $BACKUP_ROOT ]   || mkdir -p $BACKUP_ROOT
  
}

after() {
  
  # Delete working folders
  [ -d $BACKUP_ROOT ]   && rm -r $BACKUP_ROOT
  
}

it_cleans_up_project_backups() {
  
  local project_name=$( get_project_name 0 )
  local timestamp
  
  # Create dummy backup files, 1 for each day for past 40 days (incl. today).
  for i in {0..39}
  do
      # Make appropriate timestamp for the filename
      # http://stackoverflow.com/questions/8747845/how-can-i-detect-bsd-vs-gnu-version-of-date-in-shell-script
      if date --version >/dev/null 2>&1
      then
        timestamp=`date --date='-"$i" day' +%Y%m%d%H%M%S`
      else
        timestamp=`date -v-"$i"d +%Y%m%d%H%M%S`
      fi
      
      # Create file
      touch $BACKUP_ROOT/$project_name-$timestamp.tar.gz
      
  done
  
  # Sleep for 2 seconds to avoid age conflicts while tests are running.
  sleep 2
  
  # Test if there are 40 backup files in the backup directory
  test `ls -1 $BACKUP_ROOT | grep ^$project_name\-[0-9]*\.tar\.gz$ | wc -l` -eq 40
  
  # Clean backups more than 30 days old
  cleanup_project_backups $project_name 30 $BACKUP_ROOT
  
  # Test if 30 backup files remain in the backup directory
  test `ls -1 $BACKUP_ROOT | grep ^$project_name\-[0-9]*\.tar\.gz$ | wc -l` -eq 30
  
  # Verify that none of the backups are more than 30 days old
  local max_life=$((30*86400)) # convert days into seconds
  for backup_file in `ls $BACKUP_ROOT | grep ^$project_name\-[0-9]*\.tar\.gz$`
  do
    if [ -f $BACKUP_ROOT/$backup_file ]
    then
      test $(get_file_age $backup_file) -lt $max_life
    fi
  done
  
  # Clean backups more 1 day old
  cleanup_project_backups $project_name 1 $BACKUP_ROOT

  # Test if 1 backup file remains in the backup directory
  test `ls -1 $BACKUP_ROOT | grep ^$project_name\-[0-9]*\.tar\.gz$ | wc -l` -eq 1
  
  # Verify that the (only) backup is less than 1 day old
  test $(get_file_age `ls $BACKUP_ROOT | grep ^$project_name\-[0-9]*\.tar\.gz$`) -lt 86400
  
}

it_cleans_up_backups() {
  
  local timestamp
  local count=$( get_count $( get_key_regex projects ) )
  
  # Create dummy backup files, for each project, 1 for each day for past 40 days (incl. today).
  for ((j=0; j<$count; ++j ))
  do
    local project_name=$( get_values $( get_key_regex projects $j name ) )
    for i in {0..39}
    do
        # Make appropriate timestamp for the filename
        # http://stackoverflow.com/questions/8747845/how-can-i-detect-bsd-vs-gnu-version-of-date-in-shell-script
        if date --version >/dev/null 2>&1
        then
          timestamp=`date --date='-"$i" day' +%Y%m%d%H%M%S`
        else
          timestamp=`date -v-"$i"d +%Y%m%d%H%M%S`
        fi
        
        # Create file
        touch $BACKUP_ROOT/$project_name-$timestamp.tar.gz
    done
  done
  
  # Sleep for 2 seconds to avoid age conflicts while tests are running.
  sleep 2
  
  # Test if there are 120 backup files in the backup directory
  test `ls -1 $BACKUP_ROOT | wc -l` -eq 120
  
  # Clean backups more than 30 days old
  cleanup_backups 30 $BACKUP_ROOT
  
  # Test if 90 backup files remain in the backup directory
  test `ls -1 $BACKUP_ROOT | wc -l` -eq 90
  
  # Clean backups more 1 day old
  cleanup_backups 1 $BACKUP_ROOT

  # Test if 1 backup file remains in the backup directory
  test `ls -1 $BACKUP_ROOT | wc -l` -eq 3
  
}
