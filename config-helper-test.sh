#!/usr/bin/env roundup

describe "config-helper: Helper functions to read config file."

SCRIPT_BASE=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

. $SCRIPT_BASE/config-helper.sh

BACKUP_CONFIG_FILE=$SCRIPT_BASE/tests/config/config-helper-test.json

it_reads_config_file() {
  
  test "`get_config`" = "\
/root string tests/backup
/lifetime number 30
/projects/0/name string project1
/projects/0/files/0/name string f
/projects/0/files/0/path string tests/files/project1/file
/projects/0/files/1/name string d
/projects/0/files/1/path string tests/files/project1/directory"
  
}

it_creates_search_regex() {
  
  test "`get_key_regex term1 term2 term3`"    = "\/term1\/term2\/term3"
  
  test "`get_key_regex t1 2 t2 0 x`"          = "\/t1\/2\/t2\/0\/x"
  
  test "`get_key_regex "\/project" 0 "\/\/\/\/file" 0`" = "\/project\/0\/file\/0"
  
}

it_gets_matches() {
  
  test "`get_matches $(get_key_regex projects)`"  = "\
/projects/0/name string project1
/projects/0/files/0/name string f
/projects/0/files/0/path string tests/files/project1/file
/projects/0/files/1/name string d
/projects/0/files/1/path string tests/files/project1/directory"
  
  test "`get_matches $(get_key_regex projects 0 files 0 path)`"  = "\
/projects/0/files/0/path string tests/files/project1/file"
  
}

it_gets_values() {
  
  test "`get_values  $(get_key_regex projects)`"  = "\
project1
f
tests/files/project1/file
d
tests/files/project1/directory"
  
  test "`get_values $(get_key_regex root)`"  = "tests/backup"
  
  test "`get_values $(get_key_regex projects 0 files 0 path)`"  = "tests/files/project1/file"
  
}

it_gets_count() {
  
  # List with 1 element
  test "`get_count $(get_key_regex projects)`"  = "1"
  
  # Not a list
  test "`get_count $(get_key_regex projects 0)`"  = "0"
  
  # List with 2 elements
  test "`get_count $(get_key_regex projects 0 files)`"  = "2"
  
  # Not a list
  test "`get_count $(get_key_regex projects 0 files 0)`"  = "0"
  
  # Not a list
  test "`get_count $(get_key_regex projects 0 files 0 path)`"  = "0"
  
}

it_gets_project_id() {
  
  # Project name `project1` has ID 0
  test "`get_project_id project1`"  = "0"
  
  # No project name `random`
  test -z "`get_project_id random`"
  
}

it_gets_project_name() {
  
  # Project id 0 has name `project1`
  test "`get_project_name 0`"  = "project1"
  
  # No project id `99`
  test -z "`get_project_id 99`"
  
}
