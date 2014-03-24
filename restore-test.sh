#!/usr/bin/env roundup

describe "restore: Restores a project backup."

SCRIPT_BASE=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)
TEST_CONFIG_FILE=$SCRIPT_BASE/tests/config/restore-test.json
DIFF_EXCLUDE_PATTERNS_FILE=$SCRIPT_BASE/tests/config/exclude.txt
. $SCRIPT_BASE/config-helper.sh
BACKUP_TESTING=1
. $SCRIPT_BASE/backup.sh
. $SCRIPT_BASE/restore.sh
RESTORE_ROOT=$SCRIPT_BASE/tests/restore
FILES_ROOT=$SCRIPT_BASE/tests/files
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
  [ -d $RESTORE_ROOT ]  && rm -r $RESTORE_ROOT
  [ -d $RESTORE_ROOT ]  || mkdir -p $RESTORE_ROOT
  [ -d $TEMP_ROOT ]     && rm -r $TEMP_ROOT
  [ -d $TEMP_ROOT ]     || mkdir -p $TEMP_ROOT
  
}

after() {
  
  # Delete working folders
  [ -d $BACKUP_ROOT ]   && rm -r $BACKUP_ROOT
  [ -d $RESTORE_ROOT ]  && rm -r $RESTORE_ROOT
  [ -d $TEMP_ROOT ]     && rm -r $TEMP_ROOT
  
}

it_restores_files() {
  
  local project_name=$( get_project_name 0 )
  
  # Copy all data to restore root
  cp -r $FILES_ROOT/* $RESTORE_ROOT/
  
  # Backup files
  echo "`backup_files "$( get_key_regex projects 0 )" "$BACKUP_ROOT"`"
  
  # Empty restore folder
  [ -d $RESTORE_ROOT ]  && rm -r $RESTORE_ROOT
  [ -d $RESTORE_ROOT ]  || mkdir -p $RESTORE_ROOT
  
  # Restore files
  echo "`restore_files "projects\/0" "$BACKUP_ROOT"`"
  
  # Verify restoration
  test -z `diff -r --exclude-from='$DIFF_EXCLUDE_PATTERNS_FILE' $FILES_ROOT/$project_name $RESTORE_ROOT/$project_name`
  
}

it_restores_mysql_db() {
  
  local project_id=$( get_project_id mysql_project )
  
  if [ ! -z $project_id ]
  then
    
    # Get the database credentials
    local db_name=$( get_values $( get_key_regex projects $project_id db 0 name ) )
    local db_user=$( get_values $( get_key_regex projects $project_id db 0 user ) )
    local db_password=$( get_values $( get_key_regex projects $project_id db 0 password ) )
    
    # Load database dump
    if [ ! -z $db_user ] && [ ! -z $db_password ]
    then
      mysql --user=$db_user --password=$db_password $db_name < $MYSQL_TEST_DATA
    elif [ ! -z $db_user ]
    then
      mysql --user=$db_user $db_name < $MYSQL_TEST_DATA
    else
      mysql $db_name < $MYSQL_TEST_DATA
    fi
    
    # Switch back to test config
    BACKUP_CONFIG_FILE=$TEST_CONFIG_FILE
    
    # Backup database
    backup_databases "$( get_key_regex projects $project_id )" "$BACKUP_ROOT"
    
    # Destroy tables in the database
    if [ ! -z $db_user ] && [ ! -z $db_password ]
    then
      mysql --user=$db_user --password=$db_password -Nse 'show tables' $db_name | while read table; do mysql -e "drop table $table" $db_name; done
    elif [ ! -z $db_user ]
    then
      mysql --user=$db_user -Nse 'show tables' $db_name | while read table; do mysql -e "drop table $table" $db_name; done
    else
      mysql -Nse 'show tables' $db_name | while read table; do mysql -e "drop table $table" $db_name; done
    fi
    
    # Restore database
    echo "`restore_databases "$( get_key_regex projects  $( get_project_id mysql_project ) )" "$BACKUP_ROOT"`"
    
    # Dump database to temp folder
    if [ ! -z $db_user ] && [ ! -z $db_password ]
    then
      mysqldump --user=$db_user --password=$db_password --opt $db_name > $TEMP_ROOT/$db_name.sql
    elif [ ! -z $db_user ]
    then
      mysqldump --user=$db_user --opt $db_name > $TEMP_ROOT/$db_name.sql
    else
      mysqldump --opt $db_name > $TEMP_ROOT/$db_name.sql
    fi
    
    # Compare database dump before and after restoration
    test -z `diff -r --exclude-from='$DIFF_EXCLUDE_PATTERNS_FILE' --ignore-matching-lines='^--' $BACKUP_ROOT $TEMP_ROOT`
    
  fi
  
}


it_restores_postgresql_db() {
  
  local project_id=$( get_project_id postgresql_project )
  
  if [ ! -z $project_id ]
  then
    
    # Get the database credentials
    local db_name=$( get_values $( get_key_regex projects $project_id db 0 name ) )
    local db_user=$( get_values $( get_key_regex projects $project_id db 0 user ) )
    
    # Load database dump
    if [ ! -z $db_user ]
    then
      psql -U $db_user -d $db_name -f $POSTGRESQL_TEST_DATA
    else
      psql -d $db_name -f $POSTGRESQL_TEST_DATA
    fi
    
    # Switch back to test config
    BACKUP_CONFIG_FILE=$TEST_CONFIG_FILE
    
    # Backup database
    backup_databases "$( get_key_regex projects $project_id )" "$BACKUP_ROOT"
    
    # Destroy tables in the database
    if [ ! -z $db_user ]
    then
      psql -U $db_user $db_name -t -c "select 'drop table \"' || tablename || '\" cascade;' from pg_tables where schemaname = 'public'"  | psql -U $db_user $db_name
    else
      psql $db_name -t -c "select 'drop table \"' || tablename || '\" cascade;' from pg_tables where schemaname = 'public'"  | psql $db_name
    fi
    
    # Restore database
    echo "`restore_databases "$( get_key_regex projects  $( get_project_id postgresql_project ) )" "$BACKUP_ROOT"`"
    
    # Dump database to temp folder
    if [ ! -z $db_user ]
    then
      pg_dump -c -U $db_user $db_name -f $TEMP_ROOT/$db_name.sql
    else
      pg_dump -c $db_name -f $TEMP_ROOT/$db_name.sql
    fi
    
    # Compare database dump before and after restoration
    test -z `diff -r --exclude-from='$DIFF_EXCLUDE_PATTERNS_FILE' --ignore-matching-lines='^--' $BACKUP_ROOT $TEMP_ROOT`
    
  fi
  
}
