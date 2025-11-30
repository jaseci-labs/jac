impl Player.postinit{
    self._layer = PLAYER_LAYER;
    self._groups = self.game.all_sprites;
    pygame.sprite.Sprite.init(self, self._groups);
    self.x *= TILESIZE;
    self.y *= TILESIZE;
    self.image = self.game.character_spritesheet.get_sprite(
        3, 2, self.width - 5, self.height - 5
    );
    self.rect = self.image.get_rect();
    self.rect.x = self.x;
    self.rect.y = self.y;
}
# Update the player actions
impl Player.update{
    self.movement();
    self.animate();
    self.collide_enemy();
    self.rect.x += self.x_change;
    self.collide_blocks('x');
    self.rect.y += self.y_change;
    self.collide_blocks('y');
    self.x_change = 0;
    self.y_change = 0;
}
# Movement controls based on arrow key pushes.
impl Player.movement{
    keys = pygame.key.get_pressed();
    if keys[pygame.K_LEFT] {
        for sprite in self.game.all_sprites {
            sprite.rect.x += PLAYER_SPEED;
        }
        self.x_change -= PLAYER_SPEED;
        self.facing = 'left';
    }
    if keys[pygame.K_RIGHT] {
        for sprite in self.game.all_sprites {
            sprite.rect.x -= PLAYER_SPEED;
        }
        self.x_change += PLAYER_SPEED;
        self.facing = 'right';
    }
    if keys[pygame.K_UP] {
        for sprite in self.game.all_sprites {
            sprite.rect.y += PLAYER_SPEED;
        }
        self.y_change -= PLAYER_SPEED;
        self.facing = 'up';
    }
    if keys[pygame.K_DOWN] {
        for sprite in self.game.all_sprites {
            sprite.rect.y -= PLAYER_SPEED;
        }
        self.y_change += PLAYER_SPEED;
        self.facing = 'down';
    }
}
# Player death when collidong with an enemy.
impl Player.collide_enemy{
    hits = pygame.sprite.spritecollide(self, self.game.enemies, False);
    if hits {
        self.kill();
        self.game.playing = False;
    }
}
# Anminate the player character.
impl Player.animate{
    down_animations = [
        self.game.character_spritesheet.get_sprite(3, 2, self.width, self.height),
        self.game.character_spritesheet.get_sprite(35, 2, self.width, self.height),
        self.game.character_spritesheet.get_sprite(68, 2, self.width, self.height)
    ];
    up_animations = [
        self.game.character_spritesheet.get_sprite(3, 34, self.width, self.height),
        self.game.character_spritesheet.get_sprite(35, 34, self.width, self.height),
        self.game.character_spritesheet.get_sprite(68, 34, self.width, self.height)
    ];
    left_animations = [
        self.game.character_spritesheet.get_sprite(3, 98, self.width, self.height),
        self.game.character_spritesheet.get_sprite(35, 98, self.width, self.height),
        self.game.character_spritesheet.get_sprite(68, 98, self.width, self.height)
    ];
    right_animations = [
        self.game.character_spritesheet.get_sprite(3, 66, self.width, self.height),
        self.game.character_spritesheet.get_sprite(35, 66, self.width, self.height),
        self.game.character_spritesheet.get_sprite(68, 66, self.width, self.height)
    ];
    if self.facing == "down" {
        if self.y_change == 0 {
            self.image = self.game.character_spritesheet.get_sprite(
                3, 2, self.width, self.height
            );
        } else {
            self.image = down_animations[math.floor(self.animation_loop)];
            self.animation_loop += 0.1;
            if self.animation_loop >= 3 {
                self.animation_loop = 1;
            }
        }
    }
    if self.facing == "up" {
        if self.y_change == 0 {
            self.image = self.game.character_spritesheet.get_sprite(
                3, 34, self.width, self.height
            );
        } else {
            self.image = up_animations[math.floor(self.animation_loop)];
            self.animation_loop += 0.1;
            if self.animation_loop >= 3 {
                self.animation_loop = 1;
            }
        }
    }
    if self.facing == "right" {
        if self.x_change == 0 {
            self.image = self.game.character_spritesheet.get_sprite(
                3, 66, self.width, self.height
            );
        } else {
            self.image = right_animations[math.floor(self.animation_loop)];
            self.animation_loop += 0.1;
            if self.animation_loop >= 3 {
                self.animation_loop = 1;
            }
        }
    }
    if self.facing == "left" {
        if self.x_change == 0 {
            self.image = self.game.character_spritesheet.get_sprite(
                3, 98, self.width, self.height
            );
        } else {
            self.image = left_animations[math.floor(self.animation_loop)];
            self.animation_loop += 0.1;
            if self.animation_loop >= 3 {
                self.animation_loop = 1;
            }
        }
    }
}
# Ability to collide with blocks without passing through.
impl Player.collide_blocks(
    direction: str
) {
    if direction == "x" {
        hits = pygame.sprite.spritecollide(self, self.game.blocks, False);
        if hits {
            if self.x_change > 0 {
                self.rect.x = hits[0].rect.left - self.rect.width;
                for sprite in self.game.all_sprites {
                    sprite.rect.x += PLAYER_SPEED;
                }
            }
            if self.x_change < 0 {
                self.rect.x = hits[0].rect.right;
                for sprite in self.game.all_sprites {
                    sprite.rect.x -= PLAYER_SPEED;
                }
            }
        }
    }
    if direction == "y" {
        hits = pygame.sprite.spritecollide(self, self.game.blocks, False);
        if hits {
            if self.y_change > 0 {
                self.rect.y = hits[0].rect.top - self.rect.height;
                for sprite in self.game.all_sprites {
                    sprite.rect.y += PLAYER_SPEED;
                }
            }
            if self.y_change < 0 {
                self.rect.y = hits[0].rect.bottom;
                for sprite in self.game.all_sprites {
                    sprite.rect.y -= PLAYER_SPEED;
                }
            }
        }
    }
}
