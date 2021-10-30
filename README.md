# owlinator
owlinator is an IoT project for the Technion, institute of technology, Israel.
its purpose is to serve as a bird-deterrent, or more specifically a pigeon-deterrent.
our code currently supports running the client on a raspberry pi device, and running the app on an android device.
once the python code runs on the client, the app can be used to monitor and control it.

## physical setup
in order to run the code, you'll need:

* a raspberry pi device
* an android device/emulator (android studio is recommended)
* a raspi camera
* 3 servo motors
* wires for the raspi
* a speaker (a complete one, including a driver card)

everything should be connected to the raspi - the servos via pins, and the rest via their designated ports.

## software setup
if you're interested in modifying our code, you'll first need to clone/fork this repo.
then you can modify both the client and the app:

### client - python
go to the `pi_code` folder, and follow the instructions there.
we used python 3.7.3 (default on raspi debian 10).
we recommend developing on a pc with pycharm, and then pulling from the pi when finished.

### app - dart
the code is found in the `owlinator_app` folder.
we used the flutter framework in android studio, using its AVD emulator.


## HOOT HOOT
