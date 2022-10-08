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

# Source some useful functions
source scripts/func.sh
LG_DIR=$(pwd)
#endregion

#region GetCameras

# Save the snapshot and the central camera if needed
cd_persist $PATH_NGP
if [ $CHOOSE ]
then
  echo
  echo "Executing ./build/testbed.exe --scene data/nerf/$OUT_NAME"
  echo "Save the camera position as $OUT_NAME"_cam".json"
  echo "Save the snapshot as $OUT_NAME"_snap".msgpack"
  echo "Check the distance to the center of the scene"
  echo 
  ./build/testbed.exe --scene data/nerf/$OUT_NAME
  echo
  echo "Introduce the distance to the center of the scene."
  read DIST

else
    echo 
    echo "You already have a trained scene and a camera position? If not use the option --choose|-ch"
    echo
fi

while [ ! $DIST ]
do
  echo
  echo "Load your camera and check the distance to the center of the scene."
  echo 
  ./build/testbed.exe --scene data/nerf/$OUT_NAME --snapshot data/nerf/$OUT_NAME/$OUT_NAME"_snap".msgpack
  echo
  echo "Introduce the distance to the center of the scene."
  read DIST
done

cd_persist $LG_DIR

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

if [ $DEBUG ]
then
  cd_persist $PATH_NGP

  echo
  echo "Load the camera Quilt/0000_quilt.json."
  echo 
  ./build/testbed.exe --scene data/nerf/$OUT_NAME --snapshot data/nerf/$OUT_NAME/$OUT_NAME"_snap".msgpack
  echo

  cd_persist $LG_DIR
fi

#endregion

#region GetFrames

# Remember we are in looking glass folder
if [[ ! -d $OUT_NAME ]]
then
  mkdir $OUT_NAME
fi

echo
echo "Execute the following command in a a windows (not WLS terminal) and the run the second part"
echo "It must be executed in $PATH_NGP"
echo "NOTE that you have to change the path to the looking glass directory for the --video_output. It has to be the windows path, not the WSL"
echo python scripts/run.py --mode nerf --scene data/nerf/$OUT_NAME --load_snapshot data/nerf/$OUT_NAME/$OUT_NAME"_snap".msgpack --video_camera_path data/nerf/$OUT_NAME/Quilt/0000_quilt.json --video_n_seconds 1 --video_fps $FRAMES --width $WIDTH --height $HEIGH --video_output \$PATH_TO_LG\$/$OUT_NAME/$OUT_NAME.mp4
