from threading import Thread

import cv2


class VideoStream:
    """camera object that controls video streaming from the Picamera"""

    def __init__(self, resolution=(640, 480)):
        # initialize the PiCamera and the camera image stream
        print("setting up cv2 video, this takes ~5 seconds...")
        self.stream = cv2.VideoCapture(0)
        self.stream.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*'MJPG'))
        self.stream.set(3, resolution[0])
        self.stream.set(4, resolution[1])

        # read first frame from the stream
        (self.grabbed, self.frame) = self.stream.read()

        # variable to control when the camera is stopped
        self.stopped = False

    def start(self):
        # start the thread that reads frames from the video stream
        Thread(target=self.update, args=()).start()
        return self

    def update(self):
        # keep looping indefinitely until the thread is stopped
        while True:
            # if the camera is stopped, stop the thread
            if self.stopped:
                # close camera resources
                self.stream.release()
                return

            # otherwise, grab the next frame from the stream
            (self.grabbed, self.frame) = self.stream.read()

    def read(self):
        # return the most recent frame
        return self.frame

    def stop(self):
        # indicate that the camera and thread should be stopped
        self.stopped = True