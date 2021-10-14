import argparse
import random
import time
from pathlib import Path
from threading import Thread
from typing import List

import cv2
import firebase_admin
import numpy as np
import pygame
from firebase_admin import credentials, db
from pygame import mixer, event

try:
    print("setting up tensorflow, this takes ~10 seconds...")
    from tflite_runtime.interpreter import Interpreter
except ImportError:
    from tensorflow.lite.python.interpreter import Interpreter


class VideoStream:
    """Camera object that controls video streaming from the Picamera"""

    def __init__(self, resolution=(640, 480)):
        # Initialize the PiCamera and the camera image stream
        self.stream = cv2.VideoCapture(0)
        self.stream.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*'MJPG'))
        self.stream.set(3, resolution[0])
        self.stream.set(4, resolution[1])

        # Read first frame from the stream
        (self.grabbed, self.frame) = self.stream.read()

        # Variable to control when the camera is stopped
        self.stopped = False

    def start(self):
        # Start the thread that reads frames from the video stream
        Thread(target=self.update, args=()).start()
        time.sleep(1)
        return self

    def update(self):
        # Keep looping indefinitely until the thread is stopped
        while True:
            # If the camera is stopped, stop the thread
            if self.stopped:
                # Close camera resources
                self.stream.release()
                return

            # Otherwise, grab the next frame from the stream
            (self.grabbed, self.frame) = self.stream.read()

    def read(self):
        # Return the most recent frame
        return self.frame

    def stop(self):
        # Indicate that the camera and thread should be stopped
        self.stopped = True


class SoundLibrary:
    SOUNDS_PATH = Path(__file__).parent / "sounds"

    def __init__(self):
        self.owl_call = self.SOUNDS_PATH / "owl_call.mp3"
        self.owl_hoot = self.SOUNDS_PATH / "owl_hoot.mp3"
        self.owl_screech = self.SOUNDS_PATH / "owl_screech.mp3"
        self.owl_surprise = self.SOUNDS_PATH / "surprise.mp3"
        self.all_sounds = [self.owl_call, self.owl_hoot, self.owl_screech, self.owl_surprise]

    def random_sound(self):
        return random.choice(self.all_sounds)


class BirdDetectionNetwork:
    MODEL_DIR_NAME = "Sample_TFLite_model"
    GRAPH_FILE_NAME = "detect.tflite"
    LABELS_FILE_NAME = "labelmap.txt"

    def __init__(self):
        cwd_path = Path.cwd()

        # Path to .tflite file, and .txt file, which contain the model network and labels
        self.path_to_model = cwd_path / self.MODEL_DIR_NAME / self.GRAPH_FILE_NAME
        self.path_to_labels = cwd_path / self.MODEL_DIR_NAME / self.LABELS_FILE_NAME

        self.labels = self.parse_labels()

        # Load the Tensorflow Lite model
        self.interpreter = Interpreter(model_path=str(self.path_to_model))
        self.interpreter.allocate_tensors()

        # Get model details
        self.network_input = self.interpreter.get_input_details()
        self.network_output = self.interpreter.get_output_details()
        self.height = self.network_input[0]['shape'][1]
        self.width = self.network_input[0]['shape'][2]

        self.floating_model = (self.network_input[0]['dtype'] == np.float32)

        self.input_mean = 127.5
        self.input_std = 127.5

    def parse_labels(self) -> List[str]:
        # Load the label map
        with open(self.path_to_labels, 'r') as f:
            labels = [line.strip() for line in f.readlines()]
        # Have to do a weird fix for label map if using the COCO "starter model" from
        # https://www.tensorflow.org/lite/models/object_detection/overview
        # First label is '???', which has to be removed.
        return labels[1:]

    def transform_video_frame(self, frame_from_cam):
        # Acquire frame and resize to expected shape [1xHxWx3]
        frame = frame_from_cam.copy()
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        frame_resized = cv2.resize(frame_rgb, (self.width, self.height))
        input_data = np.expand_dims(frame_resized, axis=0)
        # Normalize pixel values if using a floating model (i.e. if model is non-quantized)
        if self.floating_model:
            input_data = (np.float32(input_data) - self.input_mean) / self.input_std
        return frame, input_data

    def run_image_through_network(self, input_data):
        """
        note: tensorflow_lite is optimized for ARM! super slow on windows.
        """
        # Perform the actual detection by running the model with the image as input
        self.interpreter.set_tensor(self.network_input[0]['index'], input_data)
        self.interpreter.invoke()

    def get_detection_results(self):
        boxes = self.interpreter.get_tensor(self.network_output[0]['index'])[0]  # Bounding box coordinates of detected objects
        classes = self.interpreter.get_tensor(self.network_output[1]['index'])[0]  # Class index of detected objects
        scores = self.interpreter.get_tensor(self.network_output[2]['index'])[0]  # Confidence of detected objects
        return boxes, classes, scores

    def get_label(self, label_id):
        return self.labels[int(label_id)]


class BigScaryOwl:
    RUN_NETWORK = False
    BIRD_CONFIDENCE = 0.5
    BIRD_LABEL = "bird"
    FIREBASE_KEY_FILE_NAME = "firebase_key.json"
    MUSIC_END_EVENT = pygame.USEREVENT + 1

    def __init__(self):
        self.bird_detection_scores: List = []
        args = self._get_input_arguments()
        self.network = BirdDetectionNetwork()

        self.sounds = SoundLibrary()

        # use pygame for the sound mixer
        pygame.init()
        mixer.init()
        mixer.music.set_endevent(self.MUSIC_END_EVENT)
        self.playing_sound = False

        self.loop_ticks = 0
        self.frame_count = 0

        self.min_confidence_threshold = float(args.threshold)
        self.im_width, self.im_height = [int(val) for val in args.resolution.split('x')]

        # Initialize frame rate calculation
        self.frame_rate_calc = 0.0
        self.freq = cv2.getTickFrequency()

        # Initialize video stream
        self.videostream = VideoStream(resolution=(self.im_width, self.im_height)).start()

        # initalize firebase app
        cred = credentials.Certificate(self.FIREBASE_KEY_FILE_NAME)
        app_data = {"databaseURL": "https://iot-project-f75da-default-rtdb.firebaseio.com/"}
        firebase_admin.initialize_app(cred, app_data)
        self.ref = db.reference("/")

    @staticmethod
    def _get_input_arguments():
        # Define and parse input arguments
        parser = argparse.ArgumentParser()
        parser.add_argument('--threshold', help='Minimum confidence threshold for displaying detected objects',
                            default=0.5)
        parser.add_argument('--resolution', help='Desired webcam resolution in WxH. If the webcam does not support the resolution entered, errors may occur.',
                            default='1280x720')
        return parser.parse_args()

    def run_video_loop(self):
        print("press q (while focused on video) to quit")
        while True:
            self._update_ticks()

            frame, input_data = self.network.transform_video_frame(self.videostream.read())
            if self.RUN_NETWORK:
                self.network.run_image_through_network(input_data)
            self.analyze_detections(frame)
            self.show_frame(frame)
            self.check_realtime_triggers()

            # Press 'q' to quit
            if cv2.waitKey(1) == ord('q'):
                break

        # Clean up
        self.kill_all_threads()
        cv2.destroyAllWindows()
        self.videostream.stop()

    def _update_ticks(self):
        if self.loop_ticks > 0:
            # Calculate framerate
            t1 = self.loop_ticks
            t2 = cv2.getTickCount()
            time_delta = (t2 - t1) / self.freq
            self.frame_rate_calc = 1 / time_delta
            self.frame_count += 1
        self.loop_ticks = cv2.getTickCount()

    def show_frame(self, frame):
        # Draw framerate in corner of frame
        cv2.putText(frame, 'FPS: {0:.2f}'.format(self.frame_rate_calc), (30, 50), cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 0), 2, cv2.LINE_AA)
        # All the results have been drawn on the frame, so it's time to display it.
        cv2.imshow('Object detector', frame)

    def analyze_detections(self, frame):
        if self.RUN_NETWORK:
            boxes, classes, scores = self.network.get_detection_results()

            # Loop over all detections and draw detection box if confidence is above minimum threshold
            is_saw_bird = False
            best_bird_score = 0
            for detection_id in range(len(scores)):
                curr_confidence = scores[detection_id]
                curr_label = self.network.get_label(classes[detection_id])

                if (curr_confidence > self.min_confidence_threshold) and (curr_confidence <= 1.0):
                    self.draw_detection(boxes, curr_label, frame, detection_id, scores)

                if curr_label == self.BIRD_LABEL:
                    is_saw_bird = True
                    best_bird_score = max(best_bird_score, curr_confidence)
                    if self._is_bird_high_certainty(curr_confidence):
                        self._bird_detected_action()
                        # print(f"bird found with confidence {curr_confidence}")
                        # self.send_data_firebase(curr_label, curr_confidence)

            if is_saw_bird:
                self.bird_detection_scores.append(best_bird_score)
        else:
            if not self.frame_count % 100:
                self._bird_detected_action()

    def _is_bird_high_certainty(self, curr_confidence):
        # TODO@niv: if len(self.bird_detection_scores) > 3 and ...
        return curr_confidence > self.BIRD_CONFIDENCE

    def _bird_detected_action(self):
        self._play_sound_action(self.sounds.random_sound())
        self._flap_wings_action()

        print(f"frames={self.frame_count}")

    def _play_sound_action(self, sound_file_name):
        for e in event.get():
            if e.type == self.MUSIC_END_EVENT:
                self.playing_sound = False

        if not self.playing_sound:
            print("starting sound_process")
            mixer.music.load(sound_file_name)
            mixer.music.play()
            self.playing_sound = True
        else:
            print("skipping sound_process because it's still running")

    def draw_detection(self, boxes, object_name, frame, i, scores):
        # Get bounding box coordinates and draw box
        # Interpreter can return coordinates that are outside of image dimensions, need to force them to be within image using max() and min()
        ymin = int(max(1, (boxes[i][0] * self.im_height)))
        xmin = int(max(1, (boxes[i][1] * self.im_width)))
        ymax = int(min(self.im_height, (boxes[i][2] * self.im_height)))
        xmax = int(min(self.im_width, (boxes[i][3] * self.im_width)))
        cv2.rectangle(frame, (xmin, ymin), (xmax, ymax), (10, 255, 0), 2)

        # Example: 'person: 72%'
        label = '%s: %d%%' % (object_name, int(scores[i] * 100))
        # Get font size
        label_size, base_line = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.7, 2)
        # Make sure not to draw label too close to top of window
        label_ymin = max(ymin, label_size[1] + 10)
        # Draw white box to put label text in
        cv2.rectangle(frame, (xmin, label_ymin - label_size[1] - 10), (xmin + label_size[0], label_ymin + base_line - 10), (255, 255, 255), cv2.FILLED)
        cv2.putText(frame, label, (xmin, label_ymin - 7), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 0), 2)  # Draw label text

    # def send_data_firebase(self, label, confidence):
    #     message = messaging.Message(
    #         data={
    #             'label': label,
    #             'confidence': confidence,
    #             'time': datetime.now(),
    #         },
    #         token=self.firebase_registration_token)
    #
    #     response = messaging.send(message)
    #     print('Successfully sent message:', response)
    def check_realtime_triggers(self):
        # self.ref.set()
        pass

    def kill_all_threads(self):
        self._stop_music()

    @staticmethod
    def _stop_music():
        mixer.music.stop()

    def _flap_wings_action(self):
        pass


if __name__ == "__main__":
    BigScaryOwl().run_video_loop()
