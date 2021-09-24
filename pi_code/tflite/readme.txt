# based on https://github.com/EdjeElectronics/TensorFlow-Lite-Object-Detection-on-Android-and-Raspberry-Pi/blob/master/Raspberry_Pi_Guide.md
sudo pip3 install virtualenv
python3 -m venv tflite1-env
source tflite1-env/bin/activate
bash get_pi_requirements.sh
python3 TFLite_detection_webcam.py --modeldir=Sample_TFLite_model

