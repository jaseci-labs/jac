"""This is the Object-Spatial Implementation of the RPG Game"""

# This game is built using the pygame module which is imported here
import pygame;
import random;
import time;

# Importing Jac codebase
include sprites;
include game_obj;
include settings.config;
include settings.map;
include utils.level_manager;

'''The walker that initiates the game and runs an instance of the game'''
walker game {
    has g: Game = None,
        last_level_id: str = '1_1000',
        current_level: int = 1,
        fwd_dir: bool = True,
        manager: LevelManager = LevelManager();

    can start_game with Root entry;
}

edge play {
    has level_id: str = '1_1000';
}

'''Start screen node which operate as the virtual root node'''
node start_screen {
    has game_started: bool = False;

    can intro_screen with game entry;
    can exit_game with game exit;
}

'''Level node which (should) have unique (ai generated) attributes'''
node level {
    has game_level: int = 1,
        level_id: str = '1_1000',
        played: bool = False,
        level_config: Map = Map(),
        level_time: float = 500000;

    can run_game with game entry;
    can exit_game with game exit;
}

with entry {
    root spawn game();
}
