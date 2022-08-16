
if [ $# -ne 1 ]
then 
  echo "Usage: $0 PATH_TO_DATA" 
  exit 1
fi

PATH_TO_DATA=$1

# Remove the temporary directories
rm -r $PATH_TO_DATA/tmp_*
# Remove the quilts frames that form the video
rm $PATH_TO_DATA/quilt_*