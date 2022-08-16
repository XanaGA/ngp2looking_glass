#!/bin/bash



#region GetArguments

################################################################################
# Help                                                                         #
################################################################################
Help()
{
   # Display Help
   echo "Script to convert a NeRF to Quilt format to be displayed in a Looking Glass device."
   echo
   echo "Syntax: nerf2quilt PATH_NGP OUT_NAME FRAME_R SECONDS WIDTH HEIGH [--angle A|--curve|--choose|--distance D|--smoothing S|--debug|--clean|--help]"
   echo "options:"
   echo "PATH_NGP           Path to the instant-ngp folder. Data will be searched in the PATH_NGP/data/nerf/OUT_NAME folder"
   echo "OUT_NAME           Name for the new folder and the quilt file. IMPORTANT: you must save the scene folder, camera trajectory (_traj) and the snapshot (_snap) with this name (and the corresponding extensions)!"
   echo "FRAME_R            Frame rate the quilt video will contain."
   echo "SECONDS            Seconds that the video will last."
   echo "WIDTH              Width of each frame (Depending on the Looking Glass device)."
   echo "HEIGH              Heigh of each frame (Depending on the Looking Glass device)."
   echo "-p|--portrait      If present the quilt is prepared for portrait. If not it is prepared for other devices"
   echo "-t|--train         If present the nerf is trained from scratch. If not, you should have a snapshot with the name OUT_NAME_snap"
   echo "-a|--angle A       Angle the user may move the head. 45 degrees by default (and recommended)."  
   echo "-c|--curve         If present, the camera trajectory will be curved. If not the trajectory is straight."  
   echo "-ch|--choose       If present, the ngp gui is displayed for the user to choose a camera trajectory. If not you must already have a trajectory and snapshot named with OUT_NAME_traj. The GUI must be closed!"
   echo "-d|--distance D    Distance to the center of the scene. If not present the npg gui is displayed with the central camera loaded and the user is asked to introduce the distance. The GUI must be closed!"
   echo "--debug            If present the ngp gui is displayed to show the camera poses aproximating the trajectory. The GUI must be closed!"  
   echo "-s|--smoothing S   Smoothing to be applied while creating the trajectory"
   echo "--clean            If present the temporary and intermediate files are removed, only the video is kept." 
   echo "-h|--help          If present help information is displayed."
   echo
}

################################################################################
# Param reading                                                                #
################################################################################

POSITIONAL_ARGS=()
# Default args
ANGLE=45.0

#Save the optional arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help) # display Help
          Help
          exit 0
      ;;
    -p|--portrait)
      PORTRAIT=1
      shift # past argument
      ;;
    -t|--train)
      TRAIN=1
      shift # past argument
      ;;
    -a|--angle)
      ANGLE="$2"
      shift # past argument
      shift # past value
      ;;
    -c|--curve)
      CURVE=1
      shift # past argument
      ;;
    -ch|--choose)
      CHOOSE=1
      shift # past argument
      ;;
    -d|--distance)
      DIST="$2"
      shift # past argument
      shift # past argument
      ;;
    --debug)
      DEBUG=1
      shift # past argument
      ;;
    --clean)
      CLEAN=1
      shift # past argument
      ;;
    -s|--smoothing)
      SMOOTHING="$2"
      shift # past argument
      shift # past argument
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

if [ $# -ne 6 ]
then 
  echo "Usage: $0 PATH_NGP OUT_NAME FRAME_R SECONDS WIDTH HEIGH [--angle A|--curve|--choose|--distance D|--debug|--help]" 
  exit 1
fi

# Save the positional arguments
PATH_NGP=$1
OUT_NAME=$2
FRAME_R=$3
# $4 will be the seconds
WIDTH=$5
HEIGH=$6

# Save the frames as FRAME_R*SECONDS
printf -v FRAMES "%.0f\n" $(echo "$FRAME_R*$4"| bc) 2> /dev/null

# Rows and columns for the quilts
if [ $PORTRAIT ]
then
  ROWS=6
  COL=8
  ASPECT_RATIO=0.75
  F_QUILT=48 # Frames per quilt image
else
  ROWS=5
  COL=9
  ASPECT_RATIO=1.777
  F_QUILT=45 # Frames per quilt image
fi

# Source some useful functions
source scripts/func.sh
LG_DIR=$(pwd)
#endregion

#region GetTrajectory

# Save the snapshot and the central camera if needed
cd_persist $PATH_NGP
if [ $TRAIN ]
then
  echo
  echo "Executing ./build/testbed.exe --scene data/nerf/$OUT_NAME"
  echo "Save the camera trajectory as $OUT_NAME"_traj".json"
  echo "Save the snapshot as $OUT_NAME"_snap".msgpack"
  echo "Check the distance to the center of the scene"
  echo 
  ./build/testbed.exe --scene data/nerf/$OUT_NAME
  echo
  echo "Introduce the distance to the center of the scene."
  read DIST

else
    echo 
    echo "Do you already have a trained scene? If not use the option --train|-t"
    echo
fi

if [[ $CHOOSE && ! $TRAIN ]]
then
  echo
  echo "Executing ./build/testbed.exe --scene data/nerf/$OUT_NAME"
  echo "Save the camera trajectory as $OUT_NAME"_traj".json"
  echo "Check the distance to the center of the scene"
  echo 
  ./build/testbed.exe --scene data/nerf/$OUT_NAME --snapshot data/nerf/$OUT_NAME/$OUT_NAME"_snap".msgpack > /dev/null
  echo
  echo "Introduce the distance to the center of the scene."
  read DIST

else
    echo 
    echo "Do you already have defined a trajectory? If not use the option --choose|-ch"
    echo
fi

while [ ! $DIST ]
do
  echo
  echo "Load your trajectory and choose a distance to the center of the scene. COMMON for all the cameras."
  echo 
  ./build/testbed.exe --scene data/nerf/$OUT_NAME --snapshot data/nerf/$OUT_NAME/$OUT_NAME"_snap".msgpack > /dev/null
  echo
  echo "Introduce the distance to the center of the scene."
  read DIST
done

cd_persist $LG_DIR

# Scrtipt that calculates and stores the poses that will form the trajectory
if [ $SMOOTHING ]
then
  python scripts/trajectories.py $PATH_NGP/data/nerf/$OUT_NAME/$OUT_NAME\_traj.json $PATH_NGP/data/nerf/$OUT_NAME/$OUT_NAME\_snap_traj.json $FRAMES --smoothing $SMOOTHING
else
  python scripts/trajectories.py $PATH_NGP/data/nerf/$OUT_NAME/$OUT_NAME\_traj.json $PATH_NGP/data/nerf/$OUT_NAME/$OUT_NAME\_snap_traj.json $FRAMES
fi

if [ $DEBUG ]
then
  cd_persist $PATH_NGP

  echo
  echo "Load the camera $OUT_NAME"_snap_traj".json."
  echo 
  ./build/testbed.exe --scene data/nerf/$OUT_NAME --snapshot data/nerf/$OUT_NAME/$OUT_NAME"_snap".msgpack > /dev/null
  echo

  cd_persist $LG_DIR
fi

#endregion

#region GetCameras

# Use half of the angle for right camera and the other half for the left
HALF_ANGLE=$(echo $ANGLE/2.0 | bc -l)

# Call the python script to save the cammera trajectory
if [[ ! -d $PATH_NGP/data/nerf/$OUT_NAME/Quilt ]]
then
  mkdir $PATH_NGP/data/nerf/$OUT_NAME/Quilt
fi

if [ $CURVE ]
then
    python scripts/cam_traj.py $PATH_NGP/data/nerf/$OUT_NAME/$OUT_NAME\_snap_traj.json $PATH_NGP/data/nerf/$OUT_NAME/Quilt/ $DIST $HALF_ANGLE --arc 
else
    python scripts/cam_traj.py $PATH_NGP/data/nerf/$OUT_NAME/$OUT_NAME\_snap_traj.json $PATH_NGP/data/nerf/$OUT_NAME/Quilt/ $DIST $HALF_ANGLE
fi

#endregion

#region GetFrames

# Remember we are in looking glass folder
mkdir -p data/$OUT_NAME

# Render the frames using the python script provided
# This may fail in WSL depending on how you build the instant-ngp project. 
# If so, use the first_part.sh execute this script from a windows terminal and then the second_part.sh
cd_persist $PATH_NGP

for (( i = 0; i < $FRAMES; i++ )) 
do
  echo "Video for frame $i"
  printf -v INDEX "%04d" $i
  mkdir -p $LG_DIR/data/$OUT_NAME/tmp_$INDEX"_frame" # Create a temporal dir for this frame
  CAM=$INDEX"_quilt.json"
  #python scripts/run.py --mode nerf --scene data/nerf/$OUT_NAME --load_snapshot data/nerf/fox/$OUT_NAME"_snap".msgpack --video_camera_path data/nerf/$OUT_NAME/Quilt/$CAM --video_n_seconds 1 --video_fps $F_QUILT --width $WIDTH --height $HEIGH --video_output $LG_DIR/data/$OUT_NAME/tmp_$INDEX"_frame"/z_$INDEX$OUT_NAME.mp4 

done

wait # wait until all the videos are rendered

# Make sure you are back in looking glass folder
cd_persist $LG_DIR/data
for (( i = 0; i < $FRAMES; i++ )) 
do
  printf -v INDEX "%04d" $i
  ffmpeg -i $OUT_NAME"/tmp_"$INDEX"_frame/z_"$INDEX$OUT_NAME".mp4" $OUT_NAME"/tmp_"$INDEX"_frame/%02d.png" &
done

wait # Wait for all the frames to be extracted
#endregion

#region ConvertToQuilt

cd_persist $OUT_NAME

i=0
for tmp_dir in ./*
do
  printf -v INDEX "%04d" $i
  COUNTER=0

  # Command for every row
  CMD=""
  FILES=""
  for file in $tmp_dir/*
  do
    if [ $COUNTER -lt $FRAMES]
    then
        FILES+=" $file"
    else 
        break
    fi

    if [[ $(((COUNTER+1)%$COL)) -eq 0 ]]
    then 
        CMD+="convert $FILES +append $tmp_dir/row$((ROWS-(COUNTER+1)/COL)).png & "
        FILES=""
    fi
    COUNTER=$((COUNTER+1))
  done

  echo $CMD

  eval "$CMD"

  if [[ $(((i+1)%5)) -eq 0 ]]
  then 
      wait
  fi

  i=$((i+1))

done

wait # wait until all the files of the rows have been saved

i=0
for tmp_dir in ./*
do
  if [[ $tmp_dir =~ tmp_.* ]]
  then
    printf -v INDEX "%04d" $i

    convert $tmp_dir/row0.png $tmp_dir/row1.png $tmp_dir/row2.png $tmp_dir/row3.png $tmp_dir/row4.png $tmp_dir/row5.png -append quilt_$INDEX.png & 

    if [[ $(((i+1)%5)) -eq 0 ]]
    then 
        wait
    fi

    i=$((i+1))
  fi

done

wait # wait until all the quilt files have been created

# Gather all the quilts in a video
ffmpeg -r $FRAME_R -f image2 -s $WIDTH"x"$HEIGH -i quilt_%04d.png -vcodec libx265 -crf 25  -pix_fmt yuv420p OUT_NAME"_qs$COL"x"$ROWS"a"$ASPECT_RATIO.mp4"

#endregion

#region CleanUp

if [ $CLEAN ]
then
  # Remove the temporary directories
  rm -r tmp_*
  # Remove the quilts frames that form the video
  rm quilt_*
fi
#endregion