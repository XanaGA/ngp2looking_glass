#This file should be sourced

cd_persist() {
    # $1 = PATH
    cd $1
}

# ngp_py_1cam() {
#     # $1 = $OUT_NAME
#     conda info --envs
#     python scripts/run.py --mode nerf --scene data/nerf/$1 --load_snapshot data/nerf/$1/$1"_snap".msgpack --video_camera_path data/nerf/$1/$1"_cam".json --gui
# }