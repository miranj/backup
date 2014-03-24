#!/bin/sh
#==================================================================================================
#
#         FILE:  cleanup.sh
#
#        USAGE:  cleanup.sh [project_name]
#
#  DESCRIPTION:  Cleans up (deletes) aged project backups i.g. age > `LIFETIME` in config file.
#                Optional parameters `project_name` used to cleanup backups for a single project.
#
#==================================================================================================

SCRIPT_BASE=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

. $SCRIPT_BASE/config-helper.sh

#===  FUNCTION  ===================================================================================
#         NAME:  cleanup_project_backups
#  DESCRIPTION:  Cleans up (deletes) aged backups for given project. i.e. age > `LIFETIME` config
# PARAMETER  1:  Project name
# PARAMETER  2:  Lifetime (number of days)
# PARAMETER  3:  Backup root folder
#==================================================================================================
function cleanup_project_backups {
  local project_name=$1
  local lifetime=$(($2*86400)) # convert days into seconds
  local backup_root=$3
  
  for backup_file in `ls $backup_root | grep ^$project_name\-[0-9]*\.tar\.gz$`
  do
    if [ -f $backup_root/$backup_file ]
    then
      
      local timestamp=`echo $backup_file | rev | cut -d'-' -f1 | rev | cut -d'.' -f1`
      
      # http://stackoverflow.com/questions/8747845/how-can-i-detect-bsd-vs-gnu-version-of-date-in-shell-script
      if date --version >/dev/null 2>&1
      then
        timestamp=`date -d "${timestamp:0:8} ${timestamp:8:2}:${timestamp:10:2}:${timestamp:12:2}" +%s`
      else
        timestamp=`date -j -f "%Y%m%d%H%M%S" "$timestamp" "+%s"`
      fi
      
      local age=$((`date +%s` - $timestamp))
      
      if [ $age -gt $lifetime ]
      then
        echo "Deleting backup: $backup_root/$backup_file"
        rm $backup_root/$backup_file
      fi
    
    fi
  done

}

#===  FUNCTION  ===================================================================================
#         NAME:  cleanup_backups
#  DESCRIPTION:  Cleans up (deletes) aged project backups i.e. backup age > `LIFETIME` config
#                Executes `cleanup_project_backups` for each project in config file.
# PARAMETER  1:  Lifetime (number of days)
# PARAMETER  2:  Backup root folder
#==================================================================================================
function cleanup_backups {
  local count=$( get_count $( get_key_regex "projects" ) )
  for ((i=0; i<$count; ++i ))
  do
    local project_name=$( get_values $( get_key_regex "projects" "$i" "name" ) )
    echo "`cleanup_project_backups "$project_name" "$@"`"
  done
}

#===  FUNCTION  ===================================================================================
#         NAME:  main
#  DESCRIPTION:  Verifies config + arguments and then initiates cleanup process
# PARAMETER  1:  Project name (optional)
#==================================================================================================
function main {
  # Get `backup_root` from config file
  local backup_root=`echo $( get_values $( get_key_regex "root" ) ) | sed -e "s/\/$//g"`
  
  # Backup root should exist in config file
  if [ -z $backup_root ]
  then
    echo "[ERROR] Backup root not in config file. Cleanup aborted."
    exit 1
  fi
  
  # Backup root should not be a file.
  if [ -f $backup_root ]
  then
    echo "[ERROR] Backup root is a file. Cleanup aborted."
    exit 1
  fi

  # Backup root should exists as a directory in the file system.
  if [ ! -d $backup_root ]
  then
      echo "[ERROR] Backup root folder not found. Cleanup aborted."
      exit 1
  fi
  
  # Capture lifetime from config file
  local lifetime=$( get_values $( get_key_regex "lifetime" ) )
  
  # Lifetime should exist in config file
  if [ -z $lifetime ]
  then
    echo "[ERROR] Backup lifetime not found in config file. Cleanup aborted."
    exit 1
  fi  
  
  # Capture project name
  local backup_project_name=$1
  
  # Project should exist in config file
  if [ ! -z $backup_project_name ] && [ -z $( get_project_id $backup_project_name ) ]
  then
    echo "[ERROR] Project not found in config file. Cleanup aborted."
    exit 1
  fi
  
  # Execute cleanup command
  if [ ! -z $backup_project_name ]
  then
    # Execute cleanup_project_backups function
    echo "`cleanup_project_backups "$backup_project_name" "$lifetime" "$backup_root"`"
  else
    # Execute cleanup_backups function
    echo "`cleanup_backups "$lifetime" "$backup_root"`"
  fi
}

# Run main if not being executed as a part of the tests.
if [ -z $BACKUP_TESTING ]
then
  main $@ >&1
fi
