#!/bin/sh
#==================================================================================================
#
#         FILE:  backup.sh
#
#        USAGE:  backup.sh [project_name]
#
#  DESCRIPTION:  Backs up all projects in the config file.
#                Optional parameter `project_name` used to backup a single project.
#
#==================================================================================================


#  Load config file + helper methods before proceeding

SCRIPT_BASE=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

. $SCRIPT_BASE/config-helper.sh

#===  FUNCTION  ===================================================================================
#         NAME:  backup_files
#  DESCRIPTION:  Loops over the list of files (from config file) and backs them up
# PARAMETER  1:  Project regex to filter project settings from config file 
# PARAMETER  2:  Backup path/destination
#==================================================================================================
function backup_files {
  local project_regex=$1
  local backup_path=$2
  local count=$( get_count $( get_key_regex $project_regex "files" ) )
  for ((i=0; i<$count; ++i ))
  do
    local db_name=$( get_values $( get_key_regex $project_regex "files" "$i" "name" ) )
    local path=$( get_values $( get_key_regex $project_regex "files" "$i" "path" ) )
    tar -cvf $backup_path/$db_name.tar -C $(dirname $path) $(basename $path) 
  done
}

#===  FUNCTION  ===================================================================================
#         NAME:  backup_databases
#  DESCRIPTION:  Loops over the list of databases (from config file) and backs them up
# PARAMETER  1:  Project regex to filter project settings from config file 
# PARAMETER  2:  Backup path/destination
#==================================================================================================
function backup_databases {
  local project_regex=$1
  local backup_path=$2
  local count=$( get_count $( get_key_regex $project_regex "db" ) )
  for ((i=0; i<$count; ++i ))
  do
    local db_name=$( get_values $( get_key_regex $project_regex "db" $i "name" ) )
    local db_args=$( get_values $( get_key_regex $project_regex "db" $i "db_args" ) )
    local db_user=$( get_values $( get_key_regex $project_regex "db" $i "user" ) )
    local db_password=$( get_values $( get_key_regex $project_regex "db" $i "password" ) )
    if [ $( get_values $( get_key_regex $project_regex "db" $i "type" ) ) == "mysql" ]
    then
      echo "Dumping MySQL db: $db_name"
      if [ ! -z $db_user ] && [ ! -z $db_password ]
      then
        mysqldump --user=$db_user --password=$db_password --opt $db_name $db_args > $backup_path/$db_name.sql
      elif [ ! -z $db_user ]
      then
        mysqldump --user=$db_user --opt $db_name $db_args > $backup_path/$db_name.sql
      else
        mysqldump --opt $db_name $db_args > $backup_path/$db_name.sql
      fi
    elif [ $( get_values $( get_key_regex $project_regex "db" $i "type" ) ) == "postgresql" ]
    then
      echo "Dumping PostgreSQL db: $db_name"
      if [ ! -z $db_user ]
      then
        pg_dump -c -U $db_user $db_args $db_name -f $backup_path/$db_name.sql
      else
        pg_dump -c $db_args $db_name -f $backup_path/$db_name.sql
      fi
    fi
  done
}

#===  FUNCTION  ===================================================================================
#         NAME:  backup_project
#  DESCRIPTION:  Backs up a single project.
#                Executes `backup_files` and `backup_db` for the given project.
# PARAMETER  1:  Project name
# PARAMETER  2:  Backup root folder
#==================================================================================================
function backup_project {
  local project_name=$1
  local backup_root=$2
  local backup_name=$project_name-`date +%Y%m%d%H%M%S`
  local backup_path=$backup_root/$backup_name
  local project_id=$( get_project_id $project_name )
  
  mkdir -p $backup_path
  
  echo "`backup_files "$( get_key_regex projects $project_id )" "$backup_path"`"
  echo "`backup_databases "$( get_key_regex projects $project_id )" "$backup_path"`"
  
  tar -zcvf $backup_path.tar.gz -C $backup_root $backup_name
  rm -r $backup_path
  
  # Backup to remote host
  local remote_host=$( get_values $( get_key_regex remote host ) )
  if [ ! -z $remote_host ]
  then
    scp $backup_path.tar.gz $remote_host:$( get_values $( get_key_regex remote path ) )
  fi
  
}

#===  FUNCTION  ===================================================================================
#         NAME:  backup_projects
#  DESCRIPTION:  Backs up all project in config file.
#                Executes `backup_project` for each project in config file.
# PARAMETER  1:  Backup root folder
#==================================================================================================
function backup_projects {
  local count=$( get_count $( get_key_regex "projects" ) )
  for ((i=0; i<$count; ++i ))
  do
    local project_name=$( get_values $( get_key_regex "projects" "$i" "name" ) )
    echo "`backup_project "$project_name" "$@"`"
  done
}

#===  FUNCTION  ===================================================================================
#         NAME:  main
#  DESCRIPTION:  Verifies config + arguments and then initiates backup process
# PARAMETER  1:  Project name (optional)
#==================================================================================================
function main {
  # Get `backup_root` from config file
  local backup_root=`echo $( get_values $( get_key_regex "root" ) ) | sed -e "s/\/$//g"`
  
  # Backup root should exist in config file
  if [ -z $backup_root ]
  then
    echo "[ERROR] Backup root not in config file. Backup aborted."
    exit 1
  fi
  
  # Backup root should not be a file.
  if [ -f $backup_root ]
  then
    echo "[ERROR] Backup root is a file. Backup aborted."
    exit 1
  fi
  
  # $1 should be a valid project name in the config file
  if [ ! -z $1 ] && [ -z $( get_project_id $1 ) ]
  then
      echo "[ERROR] Project name not found in config file. Backup aborted."
      exit 1
  fi
  
  # Capture project name
  local backup_project_name=$1
  
  # Project should exist in config file
  if [ ! -z $backup_project_name ] && [ -z $( get_project_id $backup_project_name ) ]
  then
    echo "[ERROR] Project not found in config file. Backup aborted."
    exit 1
  fi
  
  # Create backup root folder if it does not exist.
  if [ ! -d $backup_root ]
  then
    mkdir -p $backup_root 
  fi
  
  # Execute backup command
  if [ ! -z $backup_project_name ]
  then
    # Execute backup_project function
    echo "`backup_project "$backup_project_name" "$backup_root"`"
  else
    # Execute backup_projects function
    echo "`backup_projects "$backup_root"`"
  fi
}

# Run main if not being executed as a part of the tests.
if [ -z $BACKUP_TESTING ]
then
  main $@ >&1
fi
