# ngp2looking_glass
LOOKINGLASS VIDEO

A collection of scripts to display ngp scenes in Looking Glass displays.
This is the Linux version of the project, if you whish to use the Windows version through WSL you can check the windows branch.

These scripts create an image/video in quilt format that you can use in the [Looking Glass Studio](https://lookingglassfactory.com/software).

In this readme I also provide an explanantion of what the scripts are doing. You can skip that and just run them modifying the provided examples. Nevertheless, it is recommended to read that part, specially if you want to tweak or augment any script. 

**NOTE**: The program will launch the instant-ngp GUI, but you should read the messages in the command line as they will provide instructions about what steps you have to follow.

## Testing
This has been tested on the Looking Glass Portrait (the only device I have access to). I'm not even sure if the other displays support Looking Glass Studio, but you are encouraged to try them!

## Requirements
It is required to have the [instant_ngp](https://github.com/NVlabs/instant-ngp) project up and running. This will imply that you have already installed some python libraries. Although there are a few more needed, you can install them by rinning the following command inside the ngp2looking_glass folder:
```
pip install -r requirements.txt
```
The most demanding part of the pipeline is the one related with the instant-ngp, so you should not have any problem if you have it already working.

**The scripts have to be run from inside the repository folder (ngp2looking_glass)!**

## Naming
This process implies to work with different files (specially when preparing a video). For this reason we have addopted the following naming convention. Imagine that the scene we want to display is called "*example"*, located under data/nerf folder in the **instant-ngp** project:

 - **Snapshots:** We will store the snapshots as "**example_snap.msgpack**". Those will be stored using the instant ngp GUI, so they will be in the data/nerf/example folder.
 - **Camera_pose:** When storing a camera pose for a **static image** we name it as  "**example_cam.json**". Those will be stored using the instant ngp GUI, so they will be in the data/nerf/example folder.
 - **Camera_trajectory:** When storing a trajectory for a **video** we name it as  "**example_traj.json**". Those will be stored using the instant ngp GUI, so they will be in the data/nerf/example folder.
 - **Output:** This will be placed in the `ngp2looking_glass/data/example` folder (it will be created if doesn't exist). the name will follow the looking glass [convention](https://docs.lookingglassfactory.com/keyconcepts/quilts): *example_qsColumnsxRowsaAspectRatio*. The extension will be *.png* or *.mp4* depending if it's an image or a video.

Those are the names the user may be concerned about. By the way some intermediate files and folders are created. Continuing with the scene called "*example*":

 - **data/nerf/example/example_snap_cam.json:** For static images, it stores the trajectory including the three camera poses from we will take the images por the quilt. Is the one you should load if you want to *debug*.
 - **data/nerf/example/example_snap_traj.json:** For videos, it stores the reconstructed trajectory with one cameera pose per frame. If our video will contain 300 frames (5 seconds at 60 fps), this file will contain 300 camera poses. Is the one you should load if you want to *debug*. **One** per video.
 - **data/nerf/example/Quilt/XXXX_quilt.json:** For videos, it stores the three poses (left, central and right) for each camera pose that conform the video trajectory (300 in the above example). **N_FRAMES** per video.

Lastly there are some *temporary* files and folders that should be removed at the end of the task, unless there is some problem you want to debug. Those can be deleted automatically by using the option --clean. Keeping those are useful in case you want to run the script again but skiping the video rendering part for example.a

## Static Image
Given a camera pose from the user, we get an static image that we can display in the device and view it from different angles.

### General idea
In reality we get a [quilt](https://docs.lookingglassfactory.com/keyconcepts/quilts) image composed by `FRAMES` (48 for portrait display is recommended) images taken from different angles (covering the range the user is supposed to move the head around when looking at the display). This [article](http://paulbourke.net/stereographics/LookingGlass/) gives a very good explanation on how it works.

The script simply takes the camera pose provided and stores a camera trajectory file (instant-ngp format) including two more cameras, one to the left and another to the right of the original. These can be placed such the resulting trajectory is an *straight line* or an *arc* (following a sphere centred in the center of the scene). Then it renders that trajectory using the python script provided in the instant-ngp project. I will render only the frames that will form the quilt (48 frames for the portrait for example). Once we have those it will create the quilt image putting them all together.

Note that the user has to specify the distance from the camera choosen to the center of the scene. The center will have better quality and the rest will be more blurry. For example, in the fox scene we would like to consider the center to be approximately inside the fox head. You can check it by moving the camera from his position to the desidered center, as follows:

IMAGEN MOVING CAMERA

### Help display
Help screenshot

### Examples


## Video
Given a camera trajectory from the user, we get an video where that we can display in the device and view it from different angles.

### General idea
In reality we get a quilt for each frame and then put them together to form a video in which each frame can be viewed from different angles. Intuitively it is just repeating the process that we do for images, but for each frame in the video.

Note that ideally the camera should remain at the same distance from the center of the scene at every frame because of the focal point problem we mentioned above.

**Improvement:** A further improvement would be ask the user to intoduce one distance per each camera pose insted of only one for the whole video. Then we could interpolate (as we do with the scale, fov, dof, etc.) those distances to get an aproximation on where the user want the focus to be.

### Examples
