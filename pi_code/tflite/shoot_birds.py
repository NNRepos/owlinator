import argparse
import random
from pathlib import Path
from threading import Thread
from typing import List, Optional, Any

import cv2
import firebase_admin
import numpy as np
import pygame
from firebase_admin import credentials, db, firestore
from pygame import mixer, event

USE_NETWORK = False

if USE_NETWORK:
    try:
        print("setting up tensorflow, this takes ~5 seconds...")
        from tflite_runtime.interpreter import Interpreter
    except ImportError:
        from tensorflow.lite.python.interpreter import Interpreter

try:
    import RPi.GPIO as GPIO

    GPIO.setmode(GPIO.BOARD)
except ImportError:
    GPIO: Any = None
    print("gpio module not imported")


class VideoStream:
    """Camera object that controls video streaming from the Picamera"""

    def __init__(self, resolution=(640, 480)):
        # Initialize the PiCamera and the camera image stream
        print("setting up cv2 video, this takes ~5 seconds...")
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


class ServoController:
    PWM_HZ = 50

    def __init__(self, head_pin=11, right_pin=13, left_pin=15):
        GPIO.setup(head_pin, GPIO.OUT)
        GPIO.setup(right_pin, GPIO.OUT)
        GPIO.setup(left_pin, GPIO.OUT)

        # Note 11 is pin, 50 = 50Hz pulse
        self.servo_head = GPIO.PWM(head_pin, self.PWM_HZ)
        self.servo_right = GPIO.PWM(right_pin, self.PWM_HZ)
        self.servo_left = GPIO.PWM(left_pin, self.PWM_HZ)

        self.servo_head.start(0)
        self.servo_right.start(0)
        self.servo_left.start(0)

    def move_to_degree(self, servo_name, degree):
        if not 0 <= degree <= 180:
            return

        duty = 2 + round(degree / 18)
        if servo_name == "right":
            self.servo_right.ChangeDutyCycle(duty)
        elif servo_name == "left":
            self.servo_left.ChangeDutyCycle(duty)
        elif servo_name == "head":
            self.servo_head.ChangeDutyCycle(duty)

    def clean_up(self):
        self.servo_head.stop()
        self.servo_right.stop()
        self.servo_head.stop()
        GPIO.cleanup()

    def set_head_degree(self, degree):
        self.move_to_degree("head", degree)


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
    # detections
    BIRD_CONFIDENCE = 0.5
    BIRD_LABEL = "bird"

    # sounds
    MUSIC_END_EVENT = pygame.USEREVENT + 1

    # firebase
    DEVICE_ID = 1
    FIREBASE_KEY_FILE_NAME = "firebase_key.json"
    DEFAULT_DB_URL = {"databaseURL": "https://iot-project-f75da-default-rtdb.firebaseio.com/"}

    def __init__(self):
        self.bird_detection_scores: List = []
        args = self._get_input_arguments()
        self.min_confidence_threshold = float(args.threshold)
        self.im_width, self.im_height = [int(val) for val in args.resolution.split('x')]

        # bird detection
        if USE_NETWORK:
            self.network = BirdDetectionNetwork()

        # servo motor
        if GPIO is not None:
            self.servo_motors = ServoController(head_pin=args.headpin, right_pin=args.rightpin, left_pin=args.leftpin)

        # sounds
        self.sounds = SoundLibrary()

        # use pygame for the sound mixer
        pygame.init()
        mixer.init()
        mixer.music.set_endevent(self.MUSIC_END_EVENT)
        self.playing_sound = False

        # frame rate calculation
        self.loop_ticks = 0
        self.frame_count = 0
        self.frame_rate_calc = 0.0
        self.freq = cv2.getTickFrequency()

        # video stream
        self.videostream = VideoStream(resolution=(self.im_width, self.im_height)).start()

        # initalize firebase app
        cred = credentials.Certificate(self.FIREBASE_KEY_FILE_NAME)
        firebase_admin.initialize_app(cred, self.DEFAULT_DB_URL)
        firestore_client = firestore.client()

        self.users_db = db.reference("/users")
        self.detections_db = db.reference("/detections")
        self.settings_db = firestore_client.collection("Owls").document(str(self.DEVICE_ID))

        # threads
        self.triggers_thread: Optional[Thread] = None

        # settings
        self.muted = False
        self.fixed_head = False
        self.is_notifications_on = True

    @staticmethod
    def _get_input_arguments():
        # Define and parse input arguments
        parser = argparse.ArgumentParser()
        parser.add_argument('--threshold', help='Minimum confidence threshold for displaying detected objects',
                            default=0.5)
        parser.add_argument('--resolution', help='Desired webcam resolution in WxH. If the webcam does not support the resolution entered, errors may occur.',
                            default='1280x720')
        parser.add_argument('--headpin', help='head servo pin number', default=11)
        parser.add_argument('--rightpin', help='right servo pin number', default=13)
        parser.add_argument('--leftpin', help='left servo pin number', default=15)
        return parser.parse_args()

    def run_video_loop(self):
        print("press q (while focused on video) to quit")
        while True:
            self._update_ticks()

            camera_frame = self.videostream.read()
            if USE_NETWORK:
                frame, input_data = self.network.transform_video_frame(camera_frame)
                self.network.run_image_through_network(input_data)
                if self._is_bird_detected(frame):
                    self._bird_detected_action()
            else:
                frame = camera_frame
                if self.frame_count % 100 == 0:
                    self._bird_detected_action()

            self.show_frame(frame)

            self.triggers_thread = Thread(target=self.check_realtime_triggers)
            self.triggers_thread.start()
            # TODO@niv: move this to thread as well
            self.check_settings_changed()

            # Press 'q' to quit
            if cv2.waitKey(1) == ord('q'):
                break

        self._clean_up()

    def _clean_up(self):
        self.kill_all_threads()
        cv2.destroyAllWindows()
        self.videostream.stop()
        if GPIO is not None:
            self.servo_motors.clean_up()

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

    def _is_bird_detected(self, frame):
        is_action_needed = False
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
                is_action_needed = self._is_bird_high_certainty(curr_confidence)

        if is_saw_bird:
            self.bird_detection_scores.append(best_bird_score)

        return is_action_needed

    def _is_bird_high_certainty(self, curr_confidence):
        # TODO@niv: if len(self.bird_detection_scores) > 3 and ...
        return curr_confidence > self.BIRD_CONFIDENCE

    def _bird_detected_action(self):
        # self._play_sound_action(self.sounds.random_sound())
        self._flap_wings_action()

        print(f"frames={self.frame_count}")

    def _play_sound_action(self, sound_file_name=None):
        if sound_file_name is None:
            sound_file_name = self.sounds.owl_screech

        for e in event.get():
            if e.type == self.MUSIC_END_EVENT:
                self.playing_sound = False

        if (not self.playing_sound) and (not self.muted):
            print("starting sound_process")
            mixer.music.load(sound_file_name)
            mixer.music.play()
            self.playing_sound = True

    @staticmethod
    def _change_volume_setting(volume=0.2):
        if not 0 <= volume <= 1:
            return

        pygame.mixer.music.set_volume(volume)

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

    def check_realtime_triggers(self):
        """
        this takes about half a second, depending on internet speed
        """
        my_device = self.DEVICE_ID
        all_users = self.users_db.get("")
        assert isinstance(all_users, dict)

        for user in all_users:
            if my_device < len(all_users[user]["commands"]["device"]):
                my_device_commands = all_users[user]["commands"]["device"][my_device]
                for command in my_device_commands:
                    if my_device_commands[command]["applied"] == "false":
                        command_type = my_device_commands[command]["command"]
                        print(f"activating command {command_type}")
                        self._run_command(command_type)
                        my_device_commands[command]["applied"] = "true"

        self.users_db.set(all_users)

    def check_settings_changed(self):
        settings = self.settings_db.get().to_dict()["settings"]
        self.muted = settings["mute"]
        self.is_notifications_on = settings["notify"]
        self.fixed_head = settings["fixedHead"]
        if not self.muted:
            self._change_volume_setting(settings["volume"] / 100)

        if self.fixed_head and GPIO is not None:
            self.servo_motors.set_head_degree(settings["angle"])

        print("hi")

    def kill_all_threads(self):
        self._stop_music()

        if self.triggers_thread:
            self.triggers_thread.join()

    @staticmethod
    def _stop_music():
        mixer.music.stop()

    def _flap_wings_action(self):
        pass

    def _go_next_head_position(self):
        # use self.curr_head_position/duty or something
        if (not self.fixed_head) and (GPIO is not None):
            self.servo_motors.set_head_degree()

    def _run_command(self, command_type: str):
        if command_type == "Trigger Alarm":
            self._play_sound_action()
        elif command_type == "Stop Alarm":
            self._stop_music()


if __name__ == "__main__":
    BigScaryOwl().run_video_loop()
