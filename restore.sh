#!/bin/bash
#==================================================================================================
#
#         FILE:  restore.sh
#
#        USAGE:  restore.sh project_name backup_file
#
#  DESCRIPTION:  Restores all files and database from a backup file.
#
#==================================================================================================

SCRIPT_BASE=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

. $SCRIPT_BASE/config-helper.sh

#===  FUNCTION  ===================================================================================
#         NAME:  restore_files
#  DESCRIPTION:  Loops over the list of files (from config file) and restores them up
# PARAMETER  1:  Project regex to filter project settings from config file 
# PARAMETER  2:  Backup path/source
#==================================================================================================
function restore_files {
  local project_regex=$1
  local backup_path=$2
  local count=$( get_count $( get_key_regex $project_regex "files" ) )
  for ((i=0; i<$count; ++i ))
  do
    local db_name=$( get_values $( get_key_regex $project_regex "files" "$i" "name" ) )
    local path=$( get_values $( get_key_regex $project_regex "files" "$i" "path" ) )
    [ -d $(dirname $path) ] || mkdir -p $(dirname $path)
    tar -xvf $backup_path/$db_name.tar -C $(dirname $path)
  done
}

#===  FUNCTION  ===================================================================================
#         NAME:  restore_databases
#  DESCRIPTION:  Loops over the list of databases (from config file) and restores them up
# PARAMETER  1:  Project regex to filter project settings from config file 
# PARAMETER  2:  Backup path/source
#==================================================================================================
function restore_databases {
  local project_regex=$1
  local backup_path=$2
  local count=$( get_count $( get_key_regex $project_regex "db" ) )
  for ((i=0; i<$count; ++i ))
  do
    local db_name=$( get_values $( get_key_regex $project_regex "db" $i "name" ) )
    local args=$( get_values $( get_key_regex $project_regex "db" $i "args" ) )
    local db_user=$( get_values $( get_key_regex $project_regex "db" $i "user" ) )
    local db_password=$( get_values $( get_key_regex $project_regex "db" $i "password" ) )
    if [ $( get_values $( get_key_regex $project_regex "db" $i "type" ) ) == "mysql" ]
    then
      echo "Restoring MySQL db: $db_name"
      if [ ! -z $db_user ] && [ ! -z $db_password ]
      then
        mysql --user=$db_user --password=$db_password $db_name < $backup_path/$db_name.sql
      elif [ ! -z $db_user ]
      then
        mysql --user=$db_user $db_name < $backup_path/$db_name.sql
      else
        mysql $db_name < $backup_path/$db_name.sql
      fi
    elif [ $( get_values $( get_key_regex $project_regex "db" $i "type" ) ) == "postgresql" ]
    then
      echo "Restoring PostgreSQL db: $db_name"
      if [ ! -z $db_user ]
      then
        psql -U $db_user -d $db_name -f $backup_path/$db_name.sql
      else
        psql -d $db_name -f $backup_path/$db_name.sql
      fi
    fi
  done
}

#===  FUNCTION  ===================================================================================
#         NAME:  restore_project
#  DESCRIPTION:  Restores a project backup.
#                Executes `restore_files` and `restore_databases` for given project.
# PARAMETER  1:  Project name
# PARAMETER  2:  Backup source file
#==================================================================================================
function restore_project {
  local project_name=$1
  local backup_file=$2
  local backup_root=`echo $( get_values $( get_key_regex "root" ) ) | sed -e "s/\/$//g"`
  local backup_path=`echo $backup_file | sed -e "s/.tar.gz$//g"`
  local project_id=$( get_project_id $project_name )
  
  if [ $project_id ]
  then
    tar -zxvf $backup_file -C $backup_root
    echo "`restore_files "projects\/$project_id" "$backup_path"`"
    echo "`restore_databases "projects\/$project_id" "$backup_path"`"
    rm -r $backup_path
  fi
}

#===  FUNCTION  ===================================================================================
#         NAME:  main
#  DESCRIPTION:  Verifies config + arguments and then initiates restore process
# PARAMETER  1:  Project name (optional)
#==================================================================================================
function main {
  # Must have two arguments
  if [ $# -ne 2 ]
  then
    echo "[ERROR] Invalid number of arguments provided. Restore aborted."
    echo "Usage $0 project_name backup_file"
    exit 1
  fi
  
  # Capture project name
  local backup_project_name=$1
  
  # Project should exist in config file
  if [ ! -z $backup_project_name ] && [ -z $( get_project_id $backup_project_name ) ]
  then
    echo "[ERROR] Project not found in config file. Restore aborted."
    exit 1
  fi
  
  # Capture backup file
  local backup_file=$2
  
  # Backup file should exist
  if [ ! -f $backup_file ]
  then
    echo "[ERROR] Backup file not found. Restore aborted."
    exit 1
  fi
  
  # Create a backup
  echo "Creating a backup..."
  echo "`$SCRIPT_BASE/backup.sh "$backup_project_name"`"
  
  # Execute restore_project function
  echo "`restore_project "$backup_project_name" "$backup_file"`"
}

# Run main if not being executed as a part of the tests.
if [ -z $BACKUP_TESTING ]
then
  main $@ >&1
fi
