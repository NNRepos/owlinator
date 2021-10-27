import random
from pathlib import Path

import pygame
from pygame import mixer, event


class SoundPlayer:
    SOUNDS_PATH = Path(__file__).parent / "sounds"
    MUSIC_END_EVENT = pygame.USEREVENT + 1

    def __init__(self):
        # use pygame for the sound mixer
        self.playing_sound = False
        self.muted = True

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
            print(f"starting sound: {sound_file_name}")
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