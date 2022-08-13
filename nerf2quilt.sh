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
   echo "Syntax: nerf2quilt PATH_NGP OUT_NAME FRAMES WIDTH HEIGH [--angle A|--curve|--choose|--distance D|--debug|--help]"
   echo "options:"
   echo "PATH_NGP           Path to the instant-ngp folder. Data will be searched in the PATH_NGP/data/nerf/OUT_NAME folder"
   echo "OUT_NAME           Name for the new folder and the quilt file. IMPORTANT: you must save the scene folder, camera trajectory (_cam) and the snapshot (_snap) with this name (and the corresponding extensions)!"
   echo "FRAMES             Number of frames to construct the quilt. 48 for portrait, 45 for other devices."
   echo "WIDTH              Width of each frame (Depending on the Looking Glass device)."
   echo "HEIGH              Heigh of each frame (Depending on the Looking Glass device)."
   echo "-p|--portrait      If present the quilt is prepared for portrait. If not it is prepared for other devices"
   echo "-t|--train         If present the nerf is trained from scratch. If not, you should have a snapshot with the name OUT_NAME_snap"
   echo "-a|--angle A       Angle the user may move the head. 45 degrees by default (and recommended)."  
   echo "-c|--curve         If present, the camera trajectory will be curved. If not the trajectory is straight."  
   echo "-ch|--choose       If present, the ngp gui is displayed for the user to choose a central camera. If not you must already have a trajectory and snapshot named with OUT_NAME_cam. The GUI must be closed!"
   echo "-d|--distance D    Distance to the center of the scene. If not present the npg gui is displayed with the central camera loaded and the user is asked to introduce the distance. The GUI must be closed!"
   echo "--debug            If present the ngp gui is displayed with the camera trajectory (central, right and left) loaded. The GUI must be closed!"  
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
      ;;
    --debug)
      DEBUG=1
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

if [ $# -lt 5 ]
then 
  echo "Usage: $0 PATH_NGP OUT_NAME FRAMES WIDTH HEIGH [--angle A|--curve|--choose|--distance D|--debug|--help]" >&2
  exit 1
fi

# Save the positional arguments
PATH_NGP=$1
OUT_NAME=$2
FRAMES=$3
WIDTH=$4
HEIGH=$5

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

#region GetCameras

# Save the snapshot and the central camera if needed
cd_persist $PATH_NGP
if [ $TRAIN ]
then
  echo
  echo "Executing ./build/testbed --scene data/nerf/$OUT_NAME"
  echo "Save the camera pose as $OUT_NAME"_cam".json"
  echo "Save the snapshot as $OUT_NAME"_snap".msgpack"
  echo "Check the distance to the center of the scene"
  echo 
  ./build/testbed --scene data/nerf/$OUT_NAME
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
  echo "Executing ./build/testbed --scene data/nerf/$OUT_NAME"
  echo "Save the camera pose as $OUT_NAME"_cam".json"
  echo "Check the distance to the center of the scene"
  echo 
  ./build/testbed --scene data/nerf/$OUT_NAME --snapshot data/nerf/$OUT_NAME/$OUT_NAME"_snap".msgpack > /dev/null
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
  echo "Load your camera and check the distance to the center of the scene."
  echo 
  ./build/testbed --scene data/nerf/$OUT_NAME --snapshot data/nerf/$OUT_NAME/$OUT_NAME"_snap".msgpack
  echo
  echo "Introduce the distance to the center of the scene."
  read DIST
done

cd_persist $LG_DIR

# Use half of the angle for right camera and the other half for the left
HALF_ANGLE=$(echo $ANGLE/2.0 | bc -l)

# Call the python script to save the cammera trajectory
if [ $CURVE ]
then
    python scripts/cameras.py $PATH_NGP/data/nerf/$OUT_NAME/$OUT_NAME\_cam.json $PATH_NGP/data/nerf/$OUT_NAME/$OUT_NAME\_snap_cam.json $DIST $HALF_ANGLE --arc 
else
    python scripts/cameras.py $PATH_NGP/data/nerf/$OUT_NAME/$OUT_NAME\_cam.json $PATH_NGP/data/nerf/$OUT_NAME/$OUT_NAME\_snap_cam.json $DIST $HALF_ANGLE
fi

if [ $DEBUG ]
then
  cd_persist $PATH_NGP

  echo
  echo "Load the camera $OUT_NAME"_snap_cam".json."
  echo 
  ./build/testbed --scene data/nerf/$OUT_NAME --snapshot data/nerf/$OUT_NAME/$OUT_NAME"_snap".msgpack
  echo

  cd_persist $LG_DIR
fi

#endregion

#region GetFrames

# Remember we are in looking glass folder
cd_persist $LG_DIR
mkdir -p data/$OUT_NAME

# Render the frames using the python script provided
cd_persist $PATH_NGP
python scripts/run.py --mode nerf --scene data/nerf/$OUT_NAME --load_snapshot data/nerf/fox/$OUT_NAME"_snap".msgpack --video_camera_path data/nerf/$OUT_NAME/$OUT_NAME\_snap_cam.json --video_n_seconds 1 --video_fps $FRAMES --width $WIDTH --height $HEIGH --video_output $LG_DIR/data/$OUT_NAME/$OUT_NAME"_quilt".mp4

# Make sure you are back in looking glass folder
cd_persist $LG_DIR
mkdir -p tmp

ffmpeg -i "data/$OUT_NAME/$OUT_NAME"_quilt".mp4" "data/$OUT_NAME/tmp/%02d.png"

#endregion

#region ConvertToQuilt
cd_persist "data/$OUT_NAME"

COUNTER=0

# Command for every row
CMD=""
FILES=""

for file in ./tmp/*
do
    if [ $COUNTER -lt $FRAMES ]
    then
        FILES+=" $file"
    else 
        break
    fi

    if [[ $(((COUNTER+1)%$COL)) -eq 0 ]]
    then 
        CMD+="convert $FILES +append row$((ROWS-(COUNTER+1)/COL)).png & "
        FILES=""
    fi
    COUNTER=$((COUNTER+1))
done

echo $CMD

eval "$CMD"

wait

convert row0.png row1.png row2.png row3.png row4.png row5.png -append $OUT_NAME"_qs$COL"x"$ROWS"a"$ASPECT_RATIO.png"
rm -rf row?.png

#endregion