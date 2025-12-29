"""This file containes all definitions of sprites that apear in the game"""

# Importing python libraries
import pygame, random, math;
import from pygame.sprite { AbstractGroup }

# Importing settings data
include settings.config;
include settings.map;

"""
Object for impoting sprite character images.
"""
obj Spritesheet {
    has file: str;

    def postinit;
    def get_sprite(x: int, y: int, width: int, height: int) -> pygame.Surface;
}

"""
Object for the player with type pygame.sprite.Sprite
"""
obj Player(pygame.sprite.Sprite) {
    has game: Game,
        x: int,
        y: int,
        _layer: int = PLAYER_LAYER,
        width: int = TILESIZE,
        height: int = TILESIZE,
        x_change: int = 0,
        y_change: int = 0,
        facing: str = 'down',
        animation_loop: float = 1;

    def postinit;
    def update;
    def movement;
    def collide_enemy;
    def animate;
    def collide_blocks(direction: str);
}

"""
Object for enemies with type pygame.sprite.Sprite
"""
obj Enemy(pygame.sprite.Sprite) {
    has game: Game,
        x: int,
        y: int,
        _layer: int = ENEMY_LAYER,
        width: inr = TILESIZE,
        height: int = TILESIZE,
        x_change: int = 0,
        y_change: int = 0,
        animation_loop: float = 0,
        movement_loop: int = 0;

    def postinit;
    def update;
    def movement;
    def animate;
    def collide_blocks(direction: str);
}

"""
Object for blocks (Walls) with type pygame.sprite.Sprite
"""
obj Block(pygame.sprite.Sprite) {
    has game: Game,
        x: int,
        y: int,
        _layer: int = BLOCK_LAYER,
        width: int = TILESIZE,
        height: int = TILESIZE;

    def postinit;
}

"""
Object for ground with type pygame.sprite.Sprite
"""
obj Ground(pygame.sprite.Sprite) {
    has game: Game,
        x: int,
        y: int,
        _layer: int = GROUND_LAYER,
        width: int = TILESIZE,
        height: int = TILESIZE;

    def postinit;
}

""""
Object class for attacks by the player
"""
obj Attack(pygame.sprite.Sprite) {
    has game: Game,
        x: int,
        y: int,
        _layer: int = ATTACK_LAYER,
        width: int = TILESIZE,
        height: int = TILESIZE,
        animation_loop: float = 0;

    def postinit;
    def update;
    def collide;
    def animate;
}

"""
Object class for buttons used in the game (Start, Restart)
"""
obj Button {
    has x: int,
        y: int,
        width: int,
        height: int,
        fg: tuple,
        bg: tuple,
        content: str,
        fontsize: int;

    def postinit;
    def is_pressed(pos: tuple, pressed: tuple) -> bool;
}
