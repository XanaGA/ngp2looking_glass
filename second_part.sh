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
   echo "Syntax: nerf2quilt PATH_NGP OUT_NAME FRAMES WIDTH HEIGH [--help]"
   echo "options:"
   echo "PATH_NGP           Path to the instant-ngp folder. Data will be searched in the PATH_NGP/data/nerf/OUT_NAME folder"
   echo "OUT_NAME           Name for the new folder and the quilt file. IMPORTANT: you must save the scene folder, camera trajectory (_cam) and the snapshot (_snap) with this name (and the corresponding extensions)!"
   echo "FRAMES             Number of frames to construct the quilt. 48 for portrait, 45 for other devices."
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

if [ $# -lt 3 ]
then 
  echo "Usage: $0 PATH_NGP OUT_NAME FRAMES WIDTH HEIGH [--help]" >&2
  exit 1
fi

# Save the positional arguments
PATH_NGP=$1
OUT_NAME=$2
FRAMES=$3

# Rows and columns for the quilts
case $FRAMES in
    48) # portrait display
            ROWS=6
            COL=8
            ASPECT_RATIO=0.75
      ;;
    45) # other display
            ROWS=5
            COL=9
            ASPECT_RATIO=1.777
      ;;
    *)
      echo "Number of frames not supported, choose 48 for portrait or 45 for other displays"
      exit 1
      ;;
  esac

# Source some useful functions
source scripts/func.sh
LG_DIR=$(pwd)
#endregion

#region GetFrames

#python scripts/run.py --mode nerf --scene data/nerf/$OUT_NAME --load_snapshot data/nerf/fox/$OUT_NAME"_snap".msgpack --video_camera_path data/nerf/$OUT_NAME/$OUT_NAME\_cam_full.json --video_n_seconds 1 --video_fps $FRAMES --width $WIDTH --height $HEIGH --video_output $LG_DIR/$OUT_NAME.mp4

# Make sure you are back in looking glass folder
cd_persist $LG_DIR

ffmpeg -i "$OUT_NAME/$OUT_NAME.mp4" "$OUT_NAME/%02d.png"

#endregion

#region ConvertToQuilt
cd_persist $OUT_NAME

COUNTER=0
START=0

# Command for every row
CMD=""
FILES=""
pwd
for file in ./*
do
    if [ $COUNTER -lt $((START+FRAMES)) ]
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