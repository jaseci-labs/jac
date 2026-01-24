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
    has file: str,
        sheet: pygame.Surface by postinit;

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
        _layer: int by postinit,
        width: int = TILESIZE,
        height: int = TILESIZE,
        x_change: int = 0,
        y_change: int = 0,
        facing: str = 'down',
        animation_loop: float = 1,
        _groups: AbstractGroup by postinit,
        image: pygame.Surface by postinit,
        rect: pygame.Rect by postinit;

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
        width: int = TILESIZE,
        height: int = TILESIZE,
        x_change: int = 0,
        y_change: int = 0,
        animation_loop: float = 0,
        movement_loop: int = 0,
        _groups: tuple by postinit,
        image: pygame.Surface by postinit,
        facing: str by postinit,
        max_travel: int by postinit,
        rect: pygame.Rect by postinit;

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
        height: int = TILESIZE,
        _groups: tuple by postinit,
        image: pygame.Surface by postinit,
        rect: pygame.Rect by postinit;

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
        height: int = TILESIZE,
        _groups: AbstractGroup by postinit,
        image: pygame.Surface by postinit,
        rect: pygame.Rect by postinit;

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
        animation_loop: float = 0,
        _groups: tuple by postinit,
        image: pygame.Surface by postinit,
        rect: pygame.Rect by postinit;

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
        fontsize: int,
        font: pygame.font.Font by postinit,
        image: pygame.Surface by postinit,
        rect: pygame.Rect by postinit,
        text: pygame.Surface by postinit,
        text_rect: pygame.Rect by postinit;

    def postinit;
    def is_pressed(pos: tuple, pressed: tuple) -> bool;
}
