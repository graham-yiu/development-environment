#!/bin/bash
###############################################################################
# Basic script that tries to remove options in reverse order for a user-provided 
# command.
# - Command must return non-zero for failure, and zero for success.
# - Options in <options_file> are assumed to be space-separated, and options
# are independent of each other. ie. Cannot handle '-mllvm <option>'
# - Will attempt to remove items from comma-separated list such as 
#   '-list=item1,item2,...'
# For use with LLVM's 'opt' and 'llc' options
###############################################################################

Usage() {
  cat << EOF
Usage: $(basename $0) <options_file> <command> [arguments] ... 
       <options_file>   Space-separated options list. Options are assumed to be
                        independent of each other.
       <command>        Must return non-zero on failure, and zero for success.
                        Options will be supplied as command-line arguments.
       [arguments]      (Optional) list of mandatory arguments to pass to <command>.
EOF
}

IsMandatory() {
  local name=$(echo $1 | sed 's|^-\{1,2\}||')

  case "$name" in
    install-dir=*|march=*|mcpu=*)
      return 1
      ;;
  esac
  return 0
}

if [ $# -lt 2 ]; then
  Usage
  exit 1
fi

options=$1
shift
cmd="$*"

if [ ! -e $options ]; then
  echo "[ERROR] Cannot find options file '$options'.  Aborting ..."
  exit 1
fi

echo "[INFO] Remove \"--comment=.*\""
filtered_options=$(cat $options | sed -e 's|\"--comment=.*\" ||')

echo "[INFO] Remove \" \" ..."
filtered_options=$(echo $filtered_options | sed -e 's|\"||g')

echo "[INFO] Remove options in reverse order ..."
options_str=
for s in $filtered_options; do
  options_str="$s $options_str"
done
echo "[INFO] Try with no options ..."
$cmd
if [ $? -eq 0 ]; then
  echo "[INFO] Options in '$options' are not required ... "
  exit 0
fi
new_options=$filtered_options
echo "[INFO] Try with all options ..."
$cmd $new_options
if [ $? -ne 0 ]; then
  echo "[ERROR] Command does not pass with all options ... "
  exit 1
fi
removed_options=
removed_subitems=
for option in $options_str; do 
  IsMandatory $option
  if [ $? -ne 0 ]; then
    echo "[INFO] Keeping mandatory option '$option' ..."
    continue
  fi
  echo "[INFO] Trying to remove '$option' ..."
  try_new_options=
  for o in $new_options; do 
    if [ $o == $option ]; then
      continue;
    fi
    try_new_options="$try_new_options $o"
  done
  echo "[RUNNING] $cmd $try_new_options"
  $cmd $try_new_options
  if [ $? -eq 0 ]; then
    echo "[INFO] '$option' is not required ..."
    new_options=$try_new_options
    removed_options="$option $removed_options"
    continue
  fi
  # Found an option that has a (comma separated) list
  if [ `expr $option : "-[^ ]\{1,\}=[^ ]\{1,\},"` -gt 0 ]; then
    # Save the option
    option_prefix=$(echo $option | sed -e 's|\(-[^ ]\{1,\}\)=.*|\1|')
    echo "[INFO] Found list of items: $option"
    subitems=$(echo $option | cut -d= -f2 | sed -e 's|,| |g')
    echo "[INFO] Remove items in reverse order ..."
    subitems_rev=
    for i in $subitems; do
      subitems_rev="$i $subitems_rev"
    done
    new_subitems=$subitems
    for item in $subitems_rev; do 
      echo "[INFO] Trying to remove item '$item' ..."
      try_new_subitems=
      for i in $new_subitems; do 
        if [ $i == $item ]; then
          continue;
        fi
        try_new_subitems="$try_new_subitems $i"
      done
      try_new_subitems_cmd="$option_prefix=$(echo $try_new_subitems | sed -e 's| |,|g')"
      echo "[RUNNING] $cmd $try_new_options $try_new_subitems_cmd"
      $cmd $try_new_options $try_new_subitems_cmd
      if [ $? -eq 0 ]; then
        echo "[INFO] '$item' is not required ..."
        new_subitems=$try_new_subitems
        removed_subitems="$item $removed_subitems"
      fi
    done
    new_subitems_cmd="$option_prefix=$(echo $new_subitems | sed -e 's| |,|g')"
    new_options="$try_new_options $new_subitems_cmd"
    removed_options="$option_prefix=$(echo $removed_subitems | sed -e 's| |,|g') $removed_options"
  fi
done
echo "[INFO] Removed the following options: $removed_options"
echo "[INFO] Reduced options to: $new_options"
