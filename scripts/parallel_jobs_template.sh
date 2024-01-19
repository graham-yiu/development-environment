#!/bin/bash -e
###############################################################################
# Purpose: This is a template for a script that can run multiple sub-processes
#          (number controlled by 'threads').
###############################################################################

###############################################################################
# User Configuration
###############################################################################
threads=16
jobs_file=".jobs"
done_file=".done"
jobs_wait_time=2
flock_wait_time=5
###############################################################################

Run() {
  flock -x -w $flock_wait_time $jobs_file echo "$dir_name Start" >>$jobs_file

  # Run Job

  flock -x -w $flock_wait_time $done_file echo "$dir_name Cycles=$cycles" >>$done_file
}

# Make sure number of sub-processes doesn't exceed $threads parameter
CheckNumJobs() {
  while [ ! -e $jobs_file ]; do
    sleep $jobs_wait_time
  done
  local num_jobs=$(cat $jobs_file | wc -l)
  local num_done=0
  local num_progress=$threads
  if [ -e $done_file ]; then
    num_done=$(cat $done_file | wc -l)
  fi
  num_progress=`expr $num_jobs - $num_done`
  while [ $num_progress -ge $threads ]; do
    echo "[INFO] Too many jobs, wait for $jobs_wait_time second(s) ... "
    sleep $jobs_wait_time
    num_jobs=$(cat $jobs_file | wc -l)
    if [ -e $done_file ]; then
      num_done=$(cat $done_file | wc -l)
    fi
    num_progress=`expr $num_jobs - $num_done`
  done
}

###############################################################################
# MAIN
###############################################################################
rm -f $jobs_file
rm -f $done_file
# for ...
Run &
CheckNumJobs
# done ...
# wait for all sub-processes to finish
wait
