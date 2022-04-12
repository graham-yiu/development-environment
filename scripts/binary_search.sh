#!/bin/bash

###############################################################################
# This script uses compiler option that takes a numerical argument and performs
# binary search using user-supplied compile and execute scripts to find the
# first failing number.
# 
# Example:
#   M = ((end# - start#) / 2) + start#
#   > compileme -mllvm -opt-bisect-limit=M
#   > executeme ==> RC!=0
#   end# = M
#   M = ((end# - start#) / 2) + start#
#   > compileme -mllvm -opt-bisect-limit=M
#   > executeme ==> RC==0
#   start# = M
#   ...
###############################################################################

###############################################################################
# User configurations
###############################################################################
search_option="-mllvm -opt-bisect-limit="
start_num=0
end_num=100000
comp_file="compileme"
exec_file="executeme"
###############################################################################

usage() {
cat << EOF
Usage: $(basename $0) [-o <option>] [-s <#>] [-e <#>] 
       
       -o <option>  Use <option><#> for binary search (Default: '$search_option')
       -s <#>       Start at optimization <#> (Default: $start_num) 
       -e <#>       End at optimization <#> (Default: $end_num) 

       Additionally, users must supply the following executables:

       '$comp_file' Used to compile testcase/benchmark.  
         - Must take <option><#> as argument.  
         - Must return zero on success.
       '$exec_file' Used to execute testcase/benchmark.  
         - Must return zero on success, non-zero on failure.
EOF
}

compile() {
  local num=$1 
  local cmd="$comp_file ${search_option}${num}"
  $cmd
  rc=$?
  if [ $rc -ne 0 ]; then
    echo "ERROR: '$cmd' RC=$rc."
    exit $rc
  fi
}

###############################################################################
# MAIN
###############################################################################

# Process command line arguments
while [ -n "$1" ]; do
  case "$1" in
    --option|-o)
      if [ -z "$2" ]; then
        echo "ERROR: Missing argument for option '$1'. RC=1"
        usage
        exit 1
      fi
      search_option=$2
      shift
      ;;
    --start|-s)
      if [ -z "$2" ]; then
        echo "ERROR: Missing argument for option '$1'. RC=1"
        usage
        exit 1
      fi
      start_num=$2
      shift
      ;;
    --end|-e)
      if [ -z "$2" ]; then
        echo "ERROR: Missing argument for option '$1'. RC=1"
        usage
        exit 1
      fi
      end_num=$2
      shift
      ;;
    --help|-h)
      usage
      exit
      ;;
    *)
      echo "ERROR: Unrecognized option '$1'. RC=1"
      usage
      exit 1
      ;;
  esac
  shift
done

# Verify user supplied info
if [ $end_num -le $start_num ]; then
  echo "ERROR: Starting number '$start_num' must be smaller than ending number '$end_num'. RC=1"
  exit 1
fi

if [ ! -x $comp_file ]; then
  echo "ERROR: Cannot find executable file '$comp_file'. RC=1"
  exit 1
elif [ ! -x $exec_file ]; then
  echo "ERROR: Cannot find executable file '$exec_file'. RC=1"
  exit 1
fi

# Verify $exec_file returns zero when compiled with $start_num
echo "Try with ${search_option}${start_num} ... "
set -x
compile $start_num
$exec_file
rc=$?
set +x
if [ $rc -ne 0 ]; then
  echo "ERROR: Already FAILS($rc) with starting number '$start_num'. RC=1"
  exit 1
fi

# Verify $exec_file returns non-zero when compiled with $end_num
echo "Try with ${search_option}${end_num} ... "
set -x
compile $end_num
$exec_file
rc=$?
set +x
if [ $rc -eq 0 ]; then
  echo "ERROR: Already PASSES(0) with ending number '$end_num'. RC=1"
  exit 1
fi

# Try to find first failing optimization using binary search
while [ $end_num -gt $start_num ]; do
  diff=$(expr $end_num - $start_num)
  if [ $diff -eq 1 ]; then
    echo "Success! Found bad optimization using ${search_option}${end_num}."
    exit 0
  fi
  div_diff=$(expr $diff / 2)
  mid_num=$(expr $start_num + $div_diff)
  echo "Try with ${search_option}${mid_num} ... "
  set -x
  compile $mid_num
  $exec_file
  rc=$?
  set +x
  if [ $rc -eq 0 ]; then
    start_num=$mid_num
  else
    end_num=$mid_num
  fi
done
echo "Failure! Cannot find bad optimization. RC=1"
exit 1
