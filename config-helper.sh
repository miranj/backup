#!/bin/sh
#==================================================================================================
#
#         FILE:  config-helper.sh
#
#        USAGE:  config-helper.sh
#
#  DESCRIPTION:  Initialises helper method to parse config file written in JSON.
# 
# REQUIREMENTS:  json.sh <https://github.com/rcrowley/json.sh>
#
#==================================================================================================

SCRIPT_BASE=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

if [ -z $BACKUP_CONFIG_FILE ]
then
  BACKUP_CONFIG_FILE=$SCRIPT_BASE/config.json
fi


#===  FUNCTION  ===================================================================================
#         NAME:  get_config
#  DESCRIPTION:  Parses config file (using json.sh) and prints the output
#==================================================================================================
function get_config {
  echo "`$SCRIPT_BASE/lib/json.sh/bin/json.sh < $BACKUP_CONFIG_FILE`"
}

#===  FUNCTION  ===================================================================================
#         NAME:  get_key_regex
#  DESCRIPTION:  Concatenates all arguments to form a search regex.
# PARAMETER  *:  Search keys
#==================================================================================================
function get_key_regex {
  local regex=""
  for key in "$@"
  do 
    if [ ! -z $key ]
    then
      regex+="\/"`echo $key | sed -e "s/^\(\\\\\\\\\/\)*//g"`
    fi
  done
  echo $regex
}

#===  FUNCTION  ===================================================================================
#         NAME:  get_matches
#  DESCRIPTION:  Prints config file lines that match given regex
# PARAMETER  1:  Search regex
#==================================================================================================
function get_matches {
  local regex=$1
  echo "`get_config`" | egrep "^$regex"
}

#===  FUNCTION  ===================================================================================
#         NAME:  get_values
#  DESCRIPTION:  Prints the config file value (third parameter from matches) for given key
# PARAMETER  1:  Search key (regex)
#==================================================================================================
function get_values {
  local matches=$( get_matches $@ )
  echo "$matches" | cut -d' ' -f3
}

#===  FUNCTION  ===================================================================================
#         NAME:  get_count
#  DESCRIPTION:  Prints the count of values for given key (length of json lists)
# PARAMETER  1:  Search key (regex)
#==================================================================================================
function get_count {
  local regex=$1
  local matches=$( get_matches $@ )
  local count=`echo "$matches" | sed -e "s/^$regex//g" | sed -e "s/\// /g" | sed -e 's/^\ *//' | cut -d' ' -f1 | egrep "^[0-9]*$" | tail -1`
  if [ ! -z $count ] && [ -n $count ] && [ $count -ge 0 ]
  then
    echo `expr $count + 1`
  else
    echo 0
  fi
}

#===  FUNCTION  ===================================================================================
#         NAME:  get_project_id
#  DESCRIPTION:  Prints the project id (position in the list) for given project name
# PARAMETER  1:  Project name
#==================================================================================================
function get_project_id {
  local backup_project=$1
  echo "$( get_config )" | egrep "^\/projects\/[0-9]+\/name string $backup_project$" | sed -e 's/^\/ *//' | cut -d'/' -f2
}

#===  FUNCTION  ===================================================================================
#         NAME:  get_project_name
#  DESCRIPTION:  Prints the project name for given project id
# PARAMETER  1:  Project id
#==================================================================================================
function get_project_name {
  local backup_project_id=$1
  echo $( get_values $( get_key_regex projects $backup_project_id name))
}
