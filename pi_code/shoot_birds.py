import argparse
import json
import random
from datetime import datetime
from pathlib import Path
from threading import Thread
from time import sleep
from typing import List, Optional, Any, Union

import cv2
import firebase_admin
import numpy as np
import pygame
import requests
from PIL import Image
from firebase_admin import credentials, db, storage
from pygame import mixer, event

USE_NETWORK = True

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


class SoundPlayer:
    SOUNDS_PATH = Path(__file__).parent / "sounds"
    MUSIC_END_EVENT = pygame.USEREVENT + 1

    def __init__(self):
        # use pygame for the sound mixer
        self.playing_sound = False
        self.muted = True

        pygame.init()
        mixer.init()
        mixer.music.set_endevent(self.MUSIC_END_EVENT)

        self.owl_call = self.SOUNDS_PATH / "owl_call.mp3"
        self.owl_hoot = self.SOUNDS_PATH / "owl_hoot.mp3"
        self.owl_screech = self.SOUNDS_PATH / "owl_screech.mp3"
        self.owl_surprise = self.SOUNDS_PATH / "surprise.mp3"
        self.all_sounds = [self.owl_call, self.owl_hoot, self.owl_screech, self.owl_surprise]

    def random_sound(self):
        return random.choice(self.all_sounds)

    def play_sound(self, sound_file_name):
        for e in event.get():
            if e.type == self.MUSIC_END_EVENT:
                self.playing_sound = False

        if (not self.playing_sound) and (not self.muted):
            print("starting sound_process")
            mixer.music.load(sound_file_name)
            mixer.music.play()
            self.playing_sound = True

    @staticmethod
    def stop_music():
        mixer.music.stop()

    @staticmethod
    def change_volume_setting(volume=0.2):
        volume = round(volume, ndigits=2)
        if 0 <= volume <= 1:
            pygame.mixer.music.set_volume(volume)
        else:
            print(f"got illegal volume = {volume}, skipping command")


def _run_if_gpio(func):
    """
    a decorator for servo methods (we only run if GPIO was imported)
    """

    def wrapper(*args, **kwargs):
        if GPIO is not None:
            return func(*args, **kwargs)

    return wrapper


class ServoController:
    PWM_HZ = 50

    MIN_DEGREE = 0
    MAX_DEGREE = 180
    DEGREE_RANGE = MAX_DEGREE - MIN_DEGREE
    DEGREE_CENTER = MIN_DEGREE + (DEGREE_RANGE / 2)

    MIN_DUTY = 2
    MAX_DUTY = 12
    DUTY_RANGE = MAX_DUTY - MIN_DUTY

    # assuming they are divisible by each other
    DEGREE_PER_DUTY = DEGREE_RANGE // DUTY_RANGE

    SERVO_RESET = 0

    def __init__(self, head_pin=11, right_pin=13, left_pin=15):
        self.fixed_head = False

        if GPIO is not None:
            GPIO.setup(head_pin, GPIO.OUT)
            GPIO.setup(right_pin, GPIO.OUT)
            GPIO.setup(left_pin, GPIO.OUT)

            self.servo_head = GPIO.PWM(head_pin, self.PWM_HZ)
            self.servo_right = GPIO.PWM(right_pin, self.PWM_HZ)
            self.servo_left = GPIO.PWM(left_pin, self.PWM_HZ)

            self.servo_head.start(self.SERVO_RESET)
            self.servo_right.start(self.SERVO_RESET)
            self.servo_left.start(self.SERVO_RESET)

            self.move_to_degree("right", self.MIN_DEGREE)
            self.move_to_degree("left", self.DEGREE_CENTER)
            self.move_to_degree("head", self.DEGREE_CENTER)

            self.head_position = self.DEGREE_CENTER
            self.head_direction = self.DEGREE_PER_DUTY

    @_run_if_gpio
    def degree_to_duty(self, degree: int):
        return self.MIN_DUTY + (degree // self.DEGREE_PER_DUTY)

    @_run_if_gpio
    def move_to_degree(self, servo_name, degree: Union[float, int]):
        degree = int(round(degree))
        if not self.MIN_DEGREE <= degree <= self.MAX_DEGREE:
            print(f"got illegal motor degree = {degree}, skipping command")
            return

        duty = self.degree_to_duty(degree)
        if servo_name == "right":
            self.servo_right.ChangeDutyCycle(duty)
        elif servo_name == "left":
            self.servo_left.ChangeDutyCycle(duty)
        elif servo_name == "head":
            self.servo_head.ChangeDutyCycle(duty)

    @_run_if_gpio
    def clean_up(self):
        self.servo_head.stop()
        self.servo_right.stop()
        self.servo_head.stop()
        GPIO.cleanup()

    @_run_if_gpio
    def set_head_degree(self, degree):
        self.move_to_degree("head", degree)

    @_run_if_gpio
    def rotate_head(self):
        if not self.fixed_head:
            self.head_position += self.head_direction
            self.set_head_degree(self.head_position)

            # head reached min/max
            if not (self.MIN_DEGREE < self.head_position < self.MAX_DEGREE):
                self.head_direction = -self.head_direction

    @_run_if_gpio
    def flap_wings(self, times=2, sleep_time=0.5):
        for _ in range(times):
            self.move_to_degree("right", self.DEGREE_CENTER)
            self.move_to_degree("left", self.MIN_DEGREE)
            sleep(sleep_time)
            self.move_to_degree("right", self.MIN_DEGREE)
            self.move_to_degree("left", self.DEGREE_CENTER)
            sleep(sleep_time)


class BirdDetectionNetwork:
    MODEL_DIR_NAME = "Sample_TFLite_model"
    GRAPH_FILE_NAME = "detect.tflite"
    LABELS_FILE_NAME = "labelmap.txt"

    def __init__(self):
        cwd_path = Path.cwd()

        # path to .tflite file, and .txt file, which contain the model network and labels
        self.path_to_model = cwd_path / self.MODEL_DIR_NAME / self.GRAPH_FILE_NAME
        self.path_to_labels = cwd_path / self.MODEL_DIR_NAME / self.LABELS_FILE_NAME

        self.labels = self.parse_labels()

        # load the Tensorflow Lite model
        self.interpreter = Interpreter(model_path=str(self.path_to_model))
        self.interpreter.allocate_tensors()

        # get model details
        self.network_input = self.interpreter.get_input_details()
        self.network_output = self.interpreter.get_output_details()
        self.height = self.network_input[0]['shape'][1]
        self.width = self.network_input[0]['shape'][2]

        self.floating_model = (self.network_input[0]['dtype'] == np.float32)

        self.input_mean = 127.5
        self.input_std = 127.5

        # thread input and output
        self.input_frame = None
        self.output_detection_results = None
        self.is_busy = False

    def parse_labels(self) -> List[str]:
        # load the label map
        with open(self.path_to_labels, 'r') as f:
            labels = [line.strip() for line in f.readlines()]
        # first label is '???', which has to be removed.
        return labels[1:]

    def transform_video_frame(self, frame_from_cam):
        # acquire frame and resize to expected shape [1xHxWx3]
        frame = frame_from_cam.copy()
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        frame_resized = cv2.resize(frame_rgb, (self.width, self.height))
        input_data = np.expand_dims(frame_resized, axis=0)
        # normalize pixel values if using a floating model (i.e. if model is non-quantized)
        if self.floating_model:
            input_data = (np.float32(input_data) - self.input_mean) / self.input_std
        return frame, input_data

    def run_image_through_network(self, input_data):
        """
        note: tensorflow_lite is optimized for ARM! super slow on windows.
        """
        # perform the actual detection by running the model with the image as input
        self.is_busy = True
        self.interpreter.set_tensor(self.network_input[0]['index'], input_data)
        self.interpreter.invoke()
        self.output_detection_results = self.get_last_detection_results()
        self.is_busy = False

    def get_last_detection_results(self):
        boxes = self.interpreter.get_tensor(self.network_output[0]['index'])[0]
        classes = self.interpreter.get_tensor(self.network_output[1]['index'])[0]
        scores = self.interpreter.get_tensor(self.network_output[2]['index'])[0]
        return boxes, classes, scores

    def get_label(self, label_id):
        return self.labels[int(label_id)]


class FirebaseManager:
    pass


class BigScaryOwl:
    # detections
    BIRD_CONFIDENCE = 0.5
    BIRD_LABEL = "bird"

    # firebase
    # TODO@niv: move firebase handling into separate class
    DEVICE_ID = 4
    FIREBASE_KEY_FILE_NAME = "firebase_key.json"
    STORAGE_BUCKET_NAME = "taken-images"
    DEFAULT_DB_URLS = {"databaseURL": "https://iot-project-f75da-default-rtdb.firebaseio.com/",
                       "storageBucket": STORAGE_BUCKET_NAME}

    # notifications
    HEADERS_FILE_PATH = Path("notification_header.json")
    PAYLOAD_FILE_PATH = Path("notification_payload.json")

    def __init__(self):
        self.bird_detection_scores: List = []

        args = self._get_input_arguments()
        self.min_confidence_threshold = float(args.threshold)
        self.im_width, self.im_height = [int(val) for val in args.resolution.split('x')]

        # bird detection
        if USE_NETWORK:
            self.network = BirdDetectionNetwork()
            self.network_input = None
            self.network_output = None
            self.network_loop_ticks = 0
            self.network_fps = 0.0

        # servo motor
        self.servo_motors = ServoController(head_pin=args.headpin, right_pin=args.rightpin, left_pin=args.leftpin)

        # sounds
        self.mp3 = SoundPlayer()

        # frame rate calculation
        self.loop_ticks = 0
        self.frame_count = 0
        self.livestream_fps = 0.0
        self.freq = cv2.getTickFrequency()

        # video stream
        self.videostream = VideoStream(resolution=(self.im_width, self.im_height)).start()

        # initalize firebase app
        cred = credentials.Certificate(self.FIREBASE_KEY_FILE_NAME)
        firebase_admin.initialize_app(cred, self.DEFAULT_DB_URLS)

        self.user_commands_db = db.reference("/users")

        self.settings_db = db.reference(f"/owls/{self.DEVICE_ID}")

        settings: Any = self.settings_db.get("settings")
        my_user_id = settings["assicatedUid"]
        self.user_data_db = db.reference(f"/userdata/{my_user_id}")

        # TODO@niv: create folder DEVICE_ID inside bucket
        self.detections_storage = storage.bucket()

        # threads
        self.triggers_thread: Optional[Thread] = None
        self.settings_thread: Optional[Thread] = None
        self.upload_image_thread: Optional[Thread] = None
        self.network_forward_thread: Optional[Thread] = None
        self.flap_wings_thread: Optional[Thread] = None
        self.notify_thread: Optional[Thread] = None

        # settings
        self.notifies_detections = False

    @staticmethod
    def _get_input_arguments():
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
            livestream_frame = self._handle_frame_and_network(camera_frame)

            self.show_frame(livestream_frame)

            self.triggers_thread = Thread(target=self.check_realtime_triggers)
            self.triggers_thread.start()

            self.settings_thread = Thread(target=self.check_settings_changed)
            self.settings_thread.start()

            self.servo_motors.rotate_head()

            if cv2.waitKey(1) == ord('q'):
                break

        self._clean_up()

    def _handle_frame_and_network(self, camera_frame):
        if USE_NETWORK:
            livestream_frame, input_data = self.network.transform_video_frame(camera_frame)
            detections = self.network.output_detection_results

            if self.network.is_busy:
                if detections is not None:
                    self._draw_confident_detections(livestream_frame, detections)
            else:
                self._update_network_ticks()
                # give network new input
                network_input_frame = livestream_frame.copy()
                self.network.input_frame = network_input_frame

                if detections is not None:
                    # a detection was complete, we need to analyze its results
                    self._save_detection_score(detections)
                    # self._draw_confident_detections(livestream_frame, detections)
                    uploaded_frame = livestream_frame.copy()
                    if self._is_bird_high_confidence():
                        self._bird_detected_action(uploaded_frame)

                self.network_forward_thread = Thread(target=self.network.run_image_through_network, args=(input_data,))
                self.network_forward_thread.start()

        else:
            livestream_frame = camera_frame
            if self.frame_count % 500 == 0:
                self._bird_detected_action(livestream_frame)
        return livestream_frame

    def _clean_up(self):
        print("cleaning up, please wait...")
        self.kill_all_threads()
        cv2.destroyAllWindows()
        self.videostream.stop()
        self.servo_motors.clean_up()

    def _update_ticks(self):
        if self.loop_ticks > 0:
            # calculate framerate
            t1 = self.loop_ticks
            t2 = cv2.getTickCount()
            time_delta = (t2 - t1) / self.freq
            self.livestream_fps = 1 / time_delta
            self.frame_count += 1
        self.loop_ticks = cv2.getTickCount()

    def _update_network_ticks(self):
        if self.network_loop_ticks > 0:
            t1 = self.network_loop_ticks
            t2 = cv2.getTickCount()
            time_delta = (t2 - t1) / self.freq
            self.network_fps = 1 / time_delta
        self.network_loop_ticks = cv2.getTickCount()

    def show_frame(self, frame):
        # draw framerate in corner of frame
        cv2.putText(frame, 'LFPS: {0:.2f}'.format(self.livestream_fps), (30, 50), cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 0), 2, cv2.LINE_AA)
        cv2.putText(frame, 'NFPS: {0:.2f}'.format(self.network_fps), (30, 80), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 255), 2, cv2.LINE_AA)
        cv2.imshow('Object detector', frame)

    def _draw_confident_detections(self, frame, detection_results):
        boxes, classes, scores = detection_results

        # loop over all detections and draw detection box if confidence is above minimum threshold
        for detection_id in range(len(scores)):
            curr_confidence = scores[detection_id]
            curr_label = self.network.get_label(classes[detection_id])

            if (curr_confidence > self.min_confidence_threshold) and (curr_confidence <= 1.0):
                self._draw_detection(boxes, curr_label, frame, detection_id, scores)

    def _save_detection_score(self, detection_results):
        boxes, classes, scores = detection_results

        best_bird_score = 0
        for detection_id in range(len(scores)):
            curr_confidence = scores[detection_id]
            curr_label = self.network.get_label(classes[detection_id])

            if curr_label == self.BIRD_LABEL:
                best_bird_score = max(best_bird_score, curr_confidence)

        self.bird_detection_scores.append(best_bird_score)

    def _is_bird_high_confidence(self, num_scores=3):
        # look at the previous `num_scores` scores, and based on their average, decide if a bird was detected
        if len(self.bird_detection_scores) > num_scores:
            if sum(self.bird_detection_scores[-num_scores:]) / num_scores > self.BIRD_CONFIDENCE:
                return True

        return False

    def _bird_detected_action(self, frame):
        self._play_sound_action(self.mp3.random_sound())
        self._flap_wings_action()
        self._save_frame_action(frame)
        self._notify_detection_action()

        print(f"frames={self.frame_count}")

    def _play_sound_action(self, sound_file_name=None):
        if sound_file_name is None:
            sound_file_name = self.mp3.owl_screech

        self.mp3.play_sound(sound_file_name=sound_file_name)

    def _draw_detection(self, boxes, object_name, frame, i, scores):
        # get bounding box coordinates and draw box
        # interpreter can return coordinates that are outside of image dimensions, need to force them to be within image using max() and min()
        ymin = int(max(1, (boxes[i][0] * self.im_height)))
        xmin = int(max(1, (boxes[i][1] * self.im_width)))
        ymax = int(min(self.im_height, (boxes[i][2] * self.im_height)))
        xmax = int(min(self.im_width, (boxes[i][3] * self.im_width)))
        cv2.rectangle(frame, (xmin, ymin), (xmax, ymax), (10, 255, 0), 2)

        # example: 'person: 72%'
        label = '%s: %d%%' % (object_name, int(scores[i] * 100))
        # get font size
        label_size, base_line = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.7, 2)
        # make sure not to draw label too close to top of window
        label_ymin = max(ymin, label_size[1] + 10)
        # draw white box to put label text in
        cv2.rectangle(frame, (xmin, label_ymin - label_size[1] - 10), (xmin + label_size[0], label_ymin + base_line - 10), (255, 255, 255), cv2.FILLED)
        cv2.putText(frame, label, (xmin, label_ymin - 7), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 0), 2)

    def check_realtime_triggers(self):
        """
        this takes about half a second, depending on internet speed
        """
        my_device = self.DEVICE_ID
        all_users = self.user_commands_db.get("")
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

        self.user_commands_db.set(all_users)

    def check_settings_changed(self):
        settings: Any = self.settings_db.get("settings")
        self.mp3.muted = settings["mute"]
        self.notifies_detections = settings["notify"]
        self.servo_motors.fixed_head = settings["fixedHead"]
        if not self.mp3.muted:
            self.mp3.change_volume_setting(settings["volume"] / 100)

        if self.servo_motors.fixed_head and GPIO is not None:
            self.servo_motors.set_head_degree(settings["angle"])

    @property
    def all_threads(self):
        return [self.triggers_thread, self.settings_thread, self.upload_image_thread,
                self.network_forward_thread, self.flap_wings_thread, self.notify_thread]

    def kill_all_threads(self):
        self.mp3.stop_music()

        for thread in self.all_threads:
            if thread:
                thread.join()

    def _flap_wings_action(self):
        if (self.flap_wings_thread is None) or (not self.flap_wings_thread.is_alive()):
            self.flap_wings_thread = Thread(target=self.servo_motors.flap_wings)
            self.flap_wings_thread.start()

    def _run_command(self, command_type: str):
        if command_type == "Trigger Alarm":
            self._play_sound_action()
        elif command_type == "Stop Alarm":
            self.mp3.stop_music()

    def _save_frame_action(self, frame):
        timestamp = self._get_timestamp()
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        frame_image = Image.fromarray(frame_rgb)
        confidence = (self.bird_detection_scores[-1] * 100) if USE_NETWORK else 0
        full_image_name = f"{timestamp}_{self.DEVICE_ID}_{confidence}.jpg"
        full_image_path = str(Path("images") / full_image_name)

        self.last_image_uploaded_url = None
        self.upload_image_thread = Thread(target=self._upload_frame_image, args=(frame_image, full_image_name, full_image_path))
        self.upload_image_thread.start()

    def _upload_frame_image(self, frame_image, full_image_name, full_image_path):
        frame_image.save(full_image_path)

        print("uploading image to storage")
        my_new_blob = self.detections_storage.blob(full_image_name)
        my_new_blob.upload_from_filename(filename=full_image_path, content_type="image/jpg")
        fake_url = my_new_blob.public_url
        real_url = (fake_url.replace(f"storage.googleapis.com/{self.STORAGE_BUCKET_NAME}/",
                                     f"firebasestorage.googleapis.com/v0/b/{self.STORAGE_BUCKET_NAME}/o/")) + "?alt=media"

        self.last_image_uploaded_url = real_url

    @staticmethod
    def _get_timestamp():
        now = datetime.now()
        # year-month-day-hour-minute-second
        timestamp = now.strftime("%Y-%m-%d-%H-%M-%S")
        return timestamp

    def _notify_detection_action(self):
        # TODO@niv: make this a thread
        if self.notifies_detections:
            while self.last_image_uploaded_url is None:
                # wait for image to be uploaded
                sleep(1)

            url = "https://fcm.googleapis.com/fcm/send"

            payload = json.loads(self.PAYLOAD_FILE_PATH.read_text())
            payload["data"]["url"] = self.last_image_uploaded_url
            payload["to"] = self.user_data_db.get().to_dict()["notificationToken"]
            payload_json = json.dumps(payload)

            headers_dict = json.loads(self.HEADERS_FILE_PATH.read_text())

            response = requests.post(url, headers=headers_dict, data=payload_json)

            print(f"notification response: {response.text}")


if __name__ == "__main__":
    BigScaryOwl().run_video_loop()
