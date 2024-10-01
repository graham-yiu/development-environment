#!/bin/bash 

###############################################################################
# Back-up 'unresolved' files in git workspace(s)
# * This version of backup script assumes all git repos and will create hardlinks
#   to previously backed up files if unchanged
# * If ALL files are unchanged, then no new backup directory is created
###############################################################################
# User configurations
###############################################################################
max_num_backup_dirs=300
max_days_backup_dirs=365
max_log_file_lines=100000

git_repos="\
  $HOME/my_git_repo \
  "
###############################################################################

g_start_time=`date +%s`
if [ $# -lt 2 ]; then
  echo "[ ERROR ] Incorrect number of arguments."
cat << EOF
Usage: $(basename $0) <source> <dest> [<log_file>]
EOF
  exit 1
fi

src_root_dir=$1
dest_root_dir=$2
log_file=$3
if [ -z "$log_file" ]; then
  log_file=$dest_root_dir/backup_unresolved.log
fi

if [ ! -d $src_root_dir ]; then
  echo "[ ERROR ] Cannot find source directory '$src_root_dir'" | tee -a $log_file
  exit 1
elif [ ! -d $dest_root_dir ]; then
  echo "[ ERROR ] Cannot find destination directory '$dest_root_dir'" | tee -a $log_file
  exit 1
fi

echo "[ `date` ]" | tee -a $log_file
# Backup open and unresolved files in git workspace
cd $src_root_dir

# Initialize environment (for running as cron job)
. $HOME/.bashrc

date_dir_name=`date +%Y-%m-%d-%Hh%Mm`
prev_backup_dir=$(ls -d $dest_root_dir/[0-9]*-[0-9]*-[0-9]*-[0-9]*h[0-9]*m | tail -1)
# Backup untracked and unresolved files in git workspaces
for repo in $git_repos; do
  if [ ! -d $src_root_dir/$repo ]; then
    echo "[ WARNING ] Cannot find repo '$src_root_dir/$repo'" | tee -a $log_file
    continue
  fi
  cd $src_root_dir/$repo
  unresolved=`git status --porcelain -uall | grep "^[^D][^D]" | sed -e 's|[MARC? ][MARC? ] \([^ ]*\)|\1|'` 
  # Check for differences with previous backup before creating new directory
  declare -A changed_files
  for file in $unresolved; do 
    if [ -z "$prev_backup_dir" ]; then
      changed_files["$file"]=1
      continue
    fi
    if [ ! -e $prev_backup_dir/$repo/$file ]; then
      changed_files["$file"]=1
      continue
    fi
    diff -q $src_root_dir/$repo/$file $prev_backup_dir/$repo/$file
    if [ $? -ne 0 ]; then
      changed_files["$file"]=1
    fi
  done
  # if any files have been changed, create new backups as required
  if [ ${#changed_files[@]} -gt 0 ]; then
    for file in $unresolved; do 
      dest_dir=`dirname $dest_root_dir/$date_dir_name/$repo/$file`
      mkdir -p $dest_dir
      if [ -n "${changed_files["$file"]}" ]; then
        echo "[ INFO ] Copy $src_root_dir/$repo/$file to $dest_dir ... " | tee -a $log_file 
        cp -fp $src_root_dir/$repo/$file $dest_root_dir/$date_dir_name/$repo/$file 2>&1 | tee -a $log_file
      else
        echo "[ INFO ] Hardlink $prev_backup_dir/$repo/$file to $dest_dir ... " | tee -a $log_file 
        ln $prev_backup_dir/$repo/$file $dest_root_dir/$date_dir_name/$repo/$file 2>&1 | tee -a $log_file
      fi 
    done
  fi
done

# Unlink files in oldest directories and remove them
if [ -n "$max_num_backup_dirs" ]; then
  num_backup_dirs=`ls -d $dest_root_dir/[0-9]*-[0-9]*-[0-9]*-[0-9]*h[0-9]*m | wc -l`
  if [ $num_backup_dirs -gt $max_num_backup_dirs ]; then
    diff=`expr $num_backup_dirs - $max_num_backup_dirs`
    rem_backup_dirs=`ls -d $dest_root_dir/[0-9]*-[0-9]*-[0-9]*-[0-9]*h[0-9]*m | head -$diff`
    for dir in $rem_backup_dirs; do 
      echo "[ INFO ] Unlinking files in '$dir' ... " | tee -a $log_file
      for file in $(find $dir/ -type f); do
        unlink $file
      done
      rm -rf $dir
    done
  fi
fi

# Unlink files in directories older than $max_days_backup_dirs and remove them 
if [ -n "$max_days_backup_dirs" ]; then
  current_epoch_time=$(date +%s)
  for dir in $(ls -d $dest_root_dir/[0-9]*-[0-9]*-[0-9]*-[0-9]*h[0-9]*m); do
    date=$(basename $dir | cut -d- -f1-3)
    epoch_time=$(date --date=$date +%s)
    diff_days=`expr $(expr $current_epoch_time - $epoch_time) / 86400`
    if [ $diff_days -ge $max_days_backup_dirs ]; then
      echo "[ INFO ] Unlinking files in '$dir' ... " | tee -a $log_file
      for file in $(find $dir/ -type f); do
        unlink $file
      done
      rm -rf $dir
    else
      break
    fi
  done
fi

# Truncate log file down to $max_log_file_lines
if [ -f $log_file ]; then
  mv -f $log_file $log_file.tmp
  tail -$max_log_file_lines $log_file.tmp >$log_file 2>&1
  rm -f $log_file.tmp
fi

g_end_time=`date +%s`
echo "[ INFO ] Total elapsed time: `expr $g_end_time - $g_start_time` seconds" | tee -a $log_file
