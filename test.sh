#!/bin/bash
#
# Run roundup tests for miranj backup.
# Roundup usage reference project: https://github.com/holman/spark
#

roundup=$(which roundup)

[ ! -z $roundup ] || {
  cat <<MESSAGE 1>&2 ;
error: roundup missing

Check out https://github.com/bmizerany/roundup for instructions on installing roundup.
MESSAGE

  exit 1;
}

$roundup ./config-helper-test.sh
$roundup ./backup-test.sh
$roundup ./restore-test.sh
$roundup ./cleanup-test.sh
