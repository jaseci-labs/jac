impl Enemy.postinit{
    self._groups = (self.game.all_sprites, self.game.enemies);
    pygame.sprite.Sprite.__init__(self, self._groups);
    self.x *= TILESIZE;
    self.y *= TILESIZE;
    self.image = self.game.enemy_spritesheet.get_sprite(3, 2, self.width, self.height);
    self.facing = random.choice(['up', 'down', 'left', 'right']);
    self.max_travel = random.randint(7, 30);
    self.rect = self.image.get_rect();
    self.rect.x = self.x;
    self.rect.y = self.y;
}
# Update the enemy actions
impl Enemy.update{
    self.movement();
    self.animate();
    self.rect.x += self.x_change;
    self.collide_blocks('x');
    self.rect.y += self.y_change;
    self.collide_blocks('y');
    self.x_change = 0;
    self.y_change = 0;
}
# Movement controls.
impl Enemy.movement{
    if self.facing == 'left' {
        self.x_change -= ENEMY_SPEED;
        self.movement_loop -= 1;
        if self.movement_loop <= -self.max_travel {
            self.facing = 'right';
        }
    }
    if self.facing == 'right' {
        self.x_change += ENEMY_SPEED;
        self.movement_loop += 1;
        if self.movement_loop >= self.max_travel {
            self.facing = 'left';
        }
    }
    if self.facing == 'up' {
        self.y_change += ENEMY_SPEED;
        self.movement_loop += 1;
        if self.movement_loop >= self.max_travel {
            self.facing = 'down';
        }
    }
    if self.facing == 'down' {
        self.y_change -= ENEMY_SPEED;
        self.movement_loop -= 1;
        if self.movement_loop <= -self.max_travel {
            self.facing = 'up';
        }
    }
}
# Anminate the enemy character.
impl Enemy.animate{
    down_animations = [
        self.game.enemy_spritesheet.get_sprite(3, 2, self.width, self.height),
        self.game.enemy_spritesheet.get_sprite(35, 2, self.width, self.height),
        self.game.enemy_spritesheet.get_sprite(68, 2, self.width, self.height)
    ];
    up_animations = [
        self.game.enemy_spritesheet.get_sprite(3, 34, self.width, self.height),
        self.game.enemy_spritesheet.get_sprite(35, 34, self.width, self.height),
        self.game.enemy_spritesheet.get_sprite(68, 34, self.width, self.height)
    ];
    left_animations = [
        self.game.enemy_spritesheet.get_sprite(3, 98, self.width, self.height),
        self.game.enemy_spritesheet.get_sprite(35, 98, self.width, self.height),
        self.game.enemy_spritesheet.get_sprite(68, 98, self.width, self.height)
    ];
    right_animations = [
        self.game.enemy_spritesheet.get_sprite(3, 66, self.width, self.height),
        self.game.enemy_spritesheet.get_sprite(35, 66, self.width, self.height),
        self.game.enemy_spritesheet.get_sprite(68, 66, self.width, self.height)
    ];
    if self.facing == "down" {
        self.image = down_animations[math.floor(self.animation_loop)];
        self.animation_loop += 0.1;
        if self.animation_loop >= 3 {
            self.animation_loop = 1;
        }
    }
    if self.facing == "up" {
        self.image = up_animations[math.floor(self.animation_loop)];
        self.animation_loop += 0.1;
        if self.animation_loop >= 3 {
            self.animation_loop = 1;
        }
    }
    if self.facing == "right" {
        self.image = right_animations[math.floor(self.animation_loop)];
        self.animation_loop += 0.1;
        if self.animation_loop >= 3 {
            self.animation_loop = 1;
        }
    }
    if self.facing == "left" {
        self.image = left_animations[math.floor(self.animation_loop)];
        self.animation_loop += 0.1;
        if self.animation_loop >= 3 {
            self.animation_loop = 1;
        }
    }
}
# Ability to collide with blocks without passing through.
impl Enemy.collide_blocks(
    direction: str
) {
    if direction == "x" {
        hits = pygame.sprite.spritecollide(self, self.game.blocks, False);
        if hits {
            if self.x_change > 0 {
                self.rect.x = hits[0].rect.left - self.rect.width;
            }
            if self.x_change < 0 {
                self.rect.x = hits[0].rect.right;
            }
        }
    }
    if direction == "y" {
        hits = pygame.sprite.spritecollide(self, self.game.blocks, False);
        if hits {
            if self.y_change > 0 {
                self.rect.y = hits[0].rect.top - self.rect.height;
            }
            if self.y_change < 0 {
                self.rect.y = hits[0].rect.bottom;
            }
        }
    }
}
