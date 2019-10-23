# iVision
An assistive system for the blind based on augmented reality and machine learning

## SYSTEM DESIGN

iVision’s prototype is developed on iPhone and iOS platform, using Vision, Core ML, ARKit, etc.

1. Firstly, used the Vision framework and the Core ML framework provided by iOS to capture images from the camera, and the YoloV3 deep learning model is used to obtain the name of a specific object, the position and size of the bounding box in the two-dimensional image. You only look once (YOLO) is a real-time object detection, which is extremely fast and accurate(Redmon & Farhadi, 2018). With YoloV3, you can get the detected object name, bounding box, confidence and the time it takes. This model's training set covers many commonly used items such as cups, mice, and bananas.
2. Use the augmented reality framework to find feature point in space. Use hit-testing methods to find real-world surfaces corresponding to a point in the camera image. The two-dimensional coordinates in the screen can be converted to points in three-dimensional space by the hit-testing methods. When the number of recognition points is sufficient, the real spatial position of the object is finally obtained.
3. Convert its spatial orientation to 3D positional effects audio. The human ear judges the source direction of the sound by the time difference between the left and right and the difference in sound size and judges the distance between you and the object by the loudness(Dunai, Fajarnes, Praderas, Garcia, & Lengua, 2010; Ribeiro, Florencio, Chou, & Zhang, 2012). The user can know the spatial position of a specific object and finally find the object through the 3D positional effects audio.
4. Because blind people use touch screens with low efficiency, the system uses voice interfaces to build interactive processes. The speech-based interface combines real-time object detection model and augmented reality, into an interactive speech-based positioning and navigation device.

The picture shows the process by which the iVision app recognizes the mouse, keyboard, smartphone and marks its spatial location.
