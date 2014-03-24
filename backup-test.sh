#!/usr/bin/env roundup

describe "backup: Backs up all projects in the config file."

SCRIPT_BASE=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)
TEST_CONFIG_FILE=$SCRIPT_BASE/tests/config/backup-test.json
DIFF_EXCLUDE_PATTERNS_FILE=$SCRIPT_BASE/tests/config/exclude.txt
. $SCRIPT_BASE/config-helper.sh
BACKUP_TESTING=1
. $SCRIPT_BASE/backup.sh
TEMP_ROOT=$SCRIPT_BASE/tests/temp
MYSQL_TEST_DATA=$SCRIPT_BASE/tests/mysql.sql
POSTGRESQL_TEST_DATA=$SCRIPT_BASE/tests/postgresql.sql

before() {
  
  # Set the Backup Config File and read Backup Root
  BACKUP_CONFIG_FILE=$TEST_CONFIG_FILE
  BACKUP_ROOT=$SCRIPT_BASE/`get_values $(get_key_regex root)`
  
  # Create + clean working folders
  [ -d $BACKUP_ROOT ]   && rm -r $BACKUP_ROOT
  [ -d $BACKUP_ROOT ]   || mkdir -p $BACKUP_ROOT
  [ -d $TEMP_ROOT ]     && rm -r $TEMP_ROOT
  [ -d $TEMP_ROOT ]     || mkdir -p $TEMP_ROOT
  
}

after() {
  
  # Delete working folders
  [ -d $BACKUP_ROOT ]   && rm -r $BACKUP_ROOT
  [ -d $TEMP_ROOT ]     && rm -r $TEMP_ROOT
  
}

it_backs_up_files() {
  
  # Backup files
  backup_files "$(get_key_regex projects 0)" "$BACKUP_ROOT"
  
  # Create tar of the files in the temporary directory
  local path=$SCRIPT_BASE/$(get_values $(get_key_regex projects 0 files 0 path))
  tar -cvf $TEMP_ROOT/f.tar -C $(dirname $path) $(basename $path)
  local path=$SCRIPT_BASE/$(get_values $(get_key_regex projects 0 files 1 path))
  tar -cvf $TEMP_ROOT/d.tar -C $(dirname $path) $(basename $path)
  
  # Compare backup and temporary directories
  test -z `diff -r --exclude-from='$DIFF_EXCLUDE_PATTERNS_FILE' $BACKUP_ROOT $TEMP_ROOT`
  
}

it_backs_up_mysql_db() {
  
  local project_id=$( get_project_id mysql_project )
  
  if [ ! -z $project_id ]
  then
    
    # Get the database credentials
    local db_name=$( get_values $( get_key_regex projects $project_id db 0 name ) )
    local db_user=$( get_values $( get_key_regex projects $project_id db 0 user ) )
    local db_password=$( get_values $( get_key_regex projects $project_id db 0 password ) )
    
    # Load database dump, and export a dump in the temporary directory
    if [ ! -z $db_user ] && [ ! -z $db_password ]
    then
      mysql --user=$db_user --password=$db_password $db_name < $MYSQL_TEST_DATA
      mysqldump --user=$db_user --password=$db_password --opt $db_name > $TEMP_ROOT/$db_name.sql
    elif [ ! -z $db_user ]
    then
      mysql --user=$db_user $db_name < $MYSQL_TEST_DATA
      mysqldump --user=$db_user --opt $db_name > $TEMP_ROOT/$db_name.sql
    else
      mysql $db_name < $MYSQL_TEST_DATA
      mysqldump --opt $db_name > $TEMP_ROOT/$db_name.sql
    fi
    
    # Backup databases
    backup_databases "$( get_key_regex projects $project_id )" "$BACKUP_ROOT"
    
    # Compare database dumps in the backup and temporary directories
    test -z `diff -r --exclude-from='$DIFF_EXCLUDE_PATTERNS_FILE' --ignore-matching-lines='^--' $BACKUP_ROOT $TEMP_ROOT` 
    
  fi
  
}

it_backs_up_postgresql_db() {
  
  local project_id=$( get_project_id postgresql_project )
  
  if [ ! -z $project_id ]
  then
    
    # Get the database credentials
    local db_name=$( get_values $( get_key_regex projects $project_id db 0 name ) )
    local db_user=$( get_values $( get_key_regex projects $project_id db 0 user ) )
    
    # Load database dump, and export a dump in the temporary directory
    if [ ! -z $db_user ]
    then
      psql -U $db_user -d $db_name -f $POSTGRESQL_TEST_DATA
      pg_dump -c -U $db_user $db_name -f $TEMP_ROOT/$db_name.sql
    else
      psql -d $db_name -f $POSTGRESQL_TEST_DATA
      pg_dump -c $db_name -f $TEMP_ROOT/$db_name.sql
    fi
    
    # Backup databases
    backup_databases "$( get_key_regex projects $project_id )" "$BACKUP_ROOT"
    
    # Compare database dumps in the backup and temporary directories
    test -z `diff -r --exclude-from='$DIFF_EXCLUDE_PATTERNS_FILE' --ignore-matching-lines='^--' $BACKUP_ROOT $TEMP_ROOT` 
    
  fi
  
}

it_backs_up_remote() {
  
  # Load the Remote Backup Config File and read Backup Root
  BACKUP_CONFIG_FILE=$SCRIPT_BASE/tests/config/backup-remote-test.json
  BACKUP_ROOT=$SCRIPT_BASE/`get_values $(get_key_regex root)`
  
  local remote_host=$( get_values $( get_key_regex remote host ) )
  local project_name=$(get_project_name 0)
  
  # Backup project (including remote)
  backup_project $project_name $BACKUP_ROOT
  
  # Retrieve backups from remote host
  if [ ! -z $remote_host ]
  then
    
    # Retrieve backups from remote host
    for backup_file in `ls $BACKUP_ROOT | grep ^$project_name\-[0-9]*\.tar\.gz$`
    do
      if [ -f $BACKUP_ROOT/$backup_file ]
      then
        scp $remote_host:$( get_values $( get_key_regex remote path ) )/$backup_file $TEMP_ROOT
      fi
    done
    
    # Compare backup and temporary directories
    test -z `diff -r $BACKUP_ROOT $TEMP_ROOT`
    
    # Delete test backups from remote system
    for backup_file in `ls $BACKUP_ROOT | grep ^$project_name\-[0-9]*\.tar\.gz$`
    do
      if [ -f $BACKUP_ROOT/$backup_file ]
      then
        ssh $remote_host "rm $( get_values $( get_key_regex remote path ) )/$backup_file"
      fi
    done
  
  fi
  
}
