#!/bin/bash -x

###############################################################################
# Use rsync to backup/synchonrize directories
# * Ignores .git directory
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
  log_file=$dest_root_dir/backup_git_workspace.log
fi

# List of subdirectories to backup
sub_dirs="\
  $HOME/<my_workspace> \
  "
exclude_dirs="\
  $HOME/<build_directory> \
  "

echo "[ `date` ]" >>$log_file
for sub_dir in $sub_dirs; do
  if [ ! -d $src_root_dir/$sub_dir ]; then
    echo "  [ WARNING ] Cannot find '$src_root_dir/$sub_dir'"
    continue
  elif [ ! -d $dest_root_dir/$sub_dir ]; then
    echo "  [ INFO ] '$dest_root_dir/$sub_dir' does not exist.  Creating ..."
    mkdir -p $dest_root_dir/$sub_dir
  fi
  start_time=`date +%s`
  echo "  Backing up $sub_dir ... " >>$log_file
  rsync -a --exclude=.git --exclude=$exclude_dirs $src_root_dir/$sub_dir/ $dest_root_dir/$sub_dir >>$log_file 2>&1
  end_time=`date +%s`
  echo "    Finished in `expr $end_time - $start_time` seconds" >>$log_file
done

# Clean up log file
if [ -f $log_file ]; then
  mv -f $log_file $log_file.tmp
  tail -100000 $log_file.tmp >$log_file 2>&1
  rm -f $log_file.tmp
fi
g_end_time=`date +%s`
echo "  Total elapsed time: `expr $g_end_time - $g_start_time` seconds" >>$log_file
