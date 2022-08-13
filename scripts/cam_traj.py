import argparse
import numpy as np
import json
from scipy.spatial.transform import Rotation as R

def move_camera(og_rot, og_trans, angle, right, dist, arc=False):

    # Get the original rotation as a rotation object
    r = R.from_quat(og_rot)

    #negative rotation to turn right, positive to turn left
    sign = 1 if right else -1

    #calculate the third angle of the triangle
    third_angle = 180-90-angle

    # rotate depending on the  
    if arc:
        turn = R.from_euler('y', sign*third_angle, degrees=True)
    else:
        turn = R.from_euler('y', sign*90, degrees=True)

    # calculate the new 3D coordinates
    # Componse the original rotation with the turn you want to get
    # apply that to a unit vector with z component (starting point in the world)
    rot_vec = (r*turn).apply(np.array([0,0,1]))

    # calculate the multiplier for the inut vector
    if arc:
        mult = dist*np.sin(np.radians(angle))
    else:
        mult = dist*np.tan(np.radians(angle))
    
    new_pos = og_trans + rot_vec * mult

    # correct the orientation to face the center of the scene
    correction = R.from_euler('y', -sign*angle, degrees=True)
    new_orientation =(r*correction).as_quat()

    return new_pos, new_orientation

def quilt_mov(cam_pose, index, time, save_dir, dist, arc, angle):

    right_camera = cam_pose.copy()
    left_camera = cam_pose.copy()

    # rotation in quaterninons as a list
    rotation_q = cam_pose["R"]
    # position in 3D xyz
    trans = cam_pose["T"]

    # create the path dictionary for the left camera
    new_pos_l, new_ori_l = move_camera(rotation_q, trans, angle, right=False, dist=dist, arc=arc)
    left_camera["R"] = new_ori_l.tolist()
    left_camera["T"] = new_pos_l.tolist()

    # create the path dictionary for the right camera
    new_pos_r, new_ori_r = move_camera(rotation_q, trans, angle, right=True, dist=dist, arc=arc)
    right_camera["R"] = new_ori_r.tolist()
    right_camera["T"] = new_pos_r.tolist()

    # insert the dictionaries in the proper order
    # left first, then central, then right
    result = {
        "path": [left_camera, cam_pose, right_camera],
        "time": time
    }

    save_file = save_dir + f'{index:04}' + "_quilt.json"
    with open(save_file, 'w') as fp:
        json.dump(result, fp)

if __name__ == '__main__':

    parser = argparse.ArgumentParser(description="Given a camera pose it creates a new json file with three camera poses, by moving the central camera to the left and to the right a given angle.")
    parser.add_argument('trajectory_json', type=str, help="json file with the video trajectory")
    parser.add_argument('save_dir', type=str, help="directory where to save the quilt trajectories")
    parser.add_argument('distance', type=float, help='distance to the center of the scene')
    parser.add_argument('angle', type=float, help='angle in which the cameras are placed')
    parser.add_argument('--arc', action='store_true', help="camera trajectory straight or curved")
    args = parser.parse_args()

    # Opening JSON file
    f = open(args.trajectory_json)
    
    # returns JSON object as 
    # a dictionary
    data = json.load(f)

    # Spatial information as a dictionary with R, T, dof, fov, scale and slice
    path_list = data["path"]
    time = data["time"]

    for i in range(len(path_list)):
        cam_pose = path_list[i]

        quilt_mov(cam_pose, i, time, args.save_dir, dist=args.distance, arc=args.arc, angle=args.angle)