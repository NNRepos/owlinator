from time import sleep
from typing import Union, Any

USE_MOTORS = True

try:
    if not USE_MOTORS:
        import shalhabi

    from RPi import GPIO

    GPIO.setmode(GPIO.BOARD)
except ImportError:
    GPIO: Any = None
    print("gpio module not imported")


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

    # degree
    MIN_DEGREE = 0
    MAX_DEGREE = 180
    DEGREE_RANGE = MAX_DEGREE - MIN_DEGREE
    DEGREE_CENTER = MIN_DEGREE + DEGREE_RANGE / 2

    # duty
    MIN_DUTY = 2
    MAX_DUTY = 12
    DUTY_RANGE = MAX_DUTY - MIN_DUTY
    HEAD_START_DUTY = 2

    DEGREE_PER_DUTY = DEGREE_RANGE / DUTY_RANGE

    SERVO_RESET = 0

    # movement time
    REACTION_TIME = 0.2
    PER_DUTY_TIME = 0.1
    MIN_MOVE_THRESHOLD = 0.3

    def __init__(self, head_pin=7, right_pin=5, left_pin=3):
        self.TIME_BETWEEN_ROTATIONS = 2
        self.fixed_head = False
        self.curr_head_duty = self.HEAD_START_DUTY
        self.stop_flaps = False

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

            self.head_position = self.DEGREE_CENTER
            self.set_head_degree(self.DEGREE_CENTER)

            # this value will be added on every rotation
            self.head_direction = self.DEGREE_PER_DUTY

    def get_sleep_time(self, old_duty: float, new_duty: float) -> float:
        duty_diff = abs(new_duty - old_duty)
        expected_time = self.REACTION_TIME + duty_diff * self.PER_DUTY_TIME
        wait_time = max(self.MIN_MOVE_THRESHOLD, expected_time)
        return wait_time

    @_run_if_gpio
    def degree_to_duty(self, degree: int) -> float:
        return self.MIN_DUTY + ((degree - self.MIN_DEGREE) / self.DEGREE_PER_DUTY)

    @_run_if_gpio
    def clean_up(self):
        self.servo_head.stop()
        self.servo_right.stop()
        self.servo_head.stop()
        GPIO.cleanup()
        sleep(0.5)

    @_run_if_gpio
    def set_head_degree(self, degree: Union[float, int]):
        degree = int(round(degree))
        if not self.MIN_DEGREE <= degree <= self.MAX_DEGREE:
            print(f"got illegal motor degree = {degree}, skipping command")
            return

        if degree == self.head_position:
            return

        new_duty = self.degree_to_duty(degree)
        self.servo_head.ChangeDutyCycle(new_duty)
        old_duty = self.curr_head_duty
        self.curr_head_duty = new_duty
        wait_time = self.get_sleep_time(old_duty, new_duty)
        print(f"moving head from {old_duty} to {new_duty}, waiting {wait_time} seconds")
        sleep(wait_time)

        # if we don't start the head after moving it, it keeps moving
        self.servo_head.start(self.SERVO_RESET)
        self.head_position = degree

    @_run_if_gpio
    def rotate_head(self):
        if self.fixed_head:
            self.set_head_degree(self.head_position)

        else:
            new_position = int(round(self.head_position + self.head_direction))

            if not (self.MIN_DEGREE <= new_position <= self.MAX_DEGREE):
                # head reached min/max
                self.head_direction = -self.head_direction
                new_position += self.head_direction

            self.set_head_degree(new_position)

            sleep(self.TIME_BETWEEN_ROTATIONS)

    @_run_if_gpio
    def flap_wings(self, times=4, sleep_time=0.66):
        print(f"flapping wings {times} times, with {sleep_time} seconds in between")
        for _ in range(times):
            self.servo_right.ChangeDutyCycle(2)
            self.servo_left.ChangeDutyCycle(7)
            sleep(sleep_time)
            self.servo_right.ChangeDutyCycle(7)
            self.servo_left.ChangeDutyCycle(2)
            sleep(sleep_time)
            if self.stop_flaps:
                # a user stopped the command early
                self.stop_flaps = False
                self.servo_right.start(self.SERVO_RESET)
                self.servo_left.start(self.SERVO_RESET)
                break

        self.servo_right.start(self.SERVO_RESET)
        self.servo_left.start(self.SERVO_RESET)
