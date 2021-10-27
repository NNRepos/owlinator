from pathlib import Path
from typing import List

import cv2
import numpy as np
from tensorflow.lite.python.interpreter import Interpreter


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