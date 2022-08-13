import argparse
import numpy as np
import json
from scipy.spatial.transform import Rotation as R, RotationSpline
from scipy import interpolate
import pandas as pd

def create_tr(path_info):

    # Spatial information as a list of dictionaries dictionary with R, T, dof, fov, scale and slice
    path_df = pd.DataFrame(path_info)
    tr_np = np.atleast_1d(path_df["T"].tolist())
    rot_np = path_df["R"].tolist()
    dof = path_df["dof"].tolist() 
    fov = path_df["fov"].tolist()
    scale = path_df["scale"].tolist()
    slice = path_df["slice"].tolist()

    # Calculate the spline polynomial
    tck_tr, u = interpolate.splprep([tr_np[:,0], tr_np[:,1], tr_np[:,2]], s=args.smoothing)

    # Interpolate properly the quaternions, they can not be treated as a points in 4D
    r=R.from_quat(rot_np)
    diffs = np.sqrt(np.diff(tr_np[:,0])**2+np.diff(tr_np[:,1])**2+np.diff(tr_np[:,2])**2)
    length = diffs.sum() # Length of the lines that link the 3D positions
    cumlenth = np.insert(np.cumsum(diffs), 0, 0)
    # We use as time the normalized positions in the line 
    rot_spline = RotationSpline(cumlenth/length, r)

    # We introduce the 3D coordinates as the independent variable to interpolate the 1D data
    tck_dof, u = interpolate.splprep([tr_np[:,0], tr_np[:,1], tr_np[:,2], dof], s=args.smoothing)
    tck_fov, u = interpolate.splprep([tr_np[:,0], tr_np[:,1], tr_np[:,2], fov], s=args.smoothing)
    tck_scale, u = interpolate.splprep([tr_np[:,0], tr_np[:,1], tr_np[:,2], scale], s=args.smoothing)
    tck_slice, u = interpolate.splprep([tr_np[:,0], tr_np[:,1], tr_np[:,2], slice], s=args.smoothing)

    # Interpolate over a linear space
    u_fine = np.linspace(0,1,args.frames)
    res_tr = np.stack(interpolate.splev(u_fine, tck_tr),axis=1).tolist()
    res_rot = rot_spline(u_fine).as_quat().tolist()
    # We are only interested in the last value, the one that represent our 1D data
    res_dof = interpolate.splev(u_fine, tck_dof)[3].tolist()
    res_fov = interpolate.splev(u_fine, tck_fov)[3].tolist()
    res_scale = interpolate.splev(u_fine, tck_scale)[3].tolist()
    res_slice = interpolate.splev(u_fine, tck_slice)[3].tolist()

    dic={"T": res_tr, "R": res_rot, "dof": res_dof, "fov": res_fov, "scale": res_scale, "slice": res_slice}

    return dic

if __name__ == '__main__':

    parser = argparse.ArgumentParser(description="")
    parser.add_argument('trajectory_json', type=str, help="json file with the pose of the cameras included in the video trajectory")
    parser.add_argument('save_file', type=str, help="json file where to save the trajectory")
    parser.add_argument('frames', type=int, help='Number of frames the video will contain.')
    parser.add_argument('-s', "--smoothing", type=float, help='Smoothiong for the interpolation')
    args = parser.parse_args()

    # Opening JSON file
    f = open(args.trajectory_json)
    
    # returns JSON object as 
    # a dictionary
    data = json.load(f)

    path_dic=create_tr(data["path"])

    # Convert the dictionary in a list of dictionaries for each pose
    df = pd.DataFrame(path_dic)
    path_dic=df.to_dict("records")

    traj_dict = {"path": path_dic, "time": data["time"]}

    with open(args.save_file, 'w') as fp:
        json.dump(traj_dict, fp)


