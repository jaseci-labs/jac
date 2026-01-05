impl Attack.postinit{
    self._groups = (self.game.all_sprites, self.game.attacks);
    pygame.sprite.Sprite.init(self, self._groups);
    self.image = self.game.attack_spritesheet.get_sprite(0, 0, self.width, self.height);
    self.rect = self.image.get_rect();
    self.rect.x = self.x;
    self.rect.y = self.y;
}
# Update the attack interations
impl Attack.update{
    self.animate();
    self.collide();
}
# Ability to collide with enemies without passing through.
impl Attack.collide{
    hits = pygame.sprite.spritecollide(self, self.game.enemies, True);
}
# Anminate the attacks.
impl Attack.animate{
    direction = self.game.player.facing;
    right_animations = [
        self.game.attack_spritesheet.get_sprite(0, 64, self.width, self.height),
        self.game.attack_spritesheet.get_sprite(32, 64, self.width, self.height),
        self.game.attack_spritesheet.get_sprite(64, 64, self.width, self.height),
        self.game.attack_spritesheet.get_sprite(96, 64, self.width, self.height),
        self.game.attack_spritesheet.get_sprite(128, 64, self.width, self.height)
    ];
    down_animations = [
        self.game.attack_spritesheet.get_sprite(0, 32, self.width, self.height),
        self.game.attack_spritesheet.get_sprite(32, 32, self.width, self.height),
        self.game.attack_spritesheet.get_sprite(64, 32, self.width, self.height),
        self.game.attack_spritesheet.get_sprite(96, 32, self.width, self.height),
        self.game.attack_spritesheet.get_sprite(128, 32, self.width, self.height)
    ];
    left_animations = [
        self.game.attack_spritesheet.get_sprite(0, 96, self.width, self.height),
        self.game.attack_spritesheet.get_sprite(32, 96, self.width, self.height),
        self.game.attack_spritesheet.get_sprite(64, 96, self.width, self.height),
        self.game.attack_spritesheet.get_sprite(96, 96, self.width, self.height),
        self.game.attack_spritesheet.get_sprite(128, 96, self.width, self.height)
    ];
    up_animations = [
        self.game.attack_spritesheet.get_sprite(0, 0, self.width, self.height),
        self.game.attack_spritesheet.get_sprite(32, 0, self.width, self.height),
        self.game.attack_spritesheet.get_sprite(64, 0, self.width, self.height),
        self.game.attack_spritesheet.get_sprite(96, 0, self.width, self.height),
        self.game.attack_spritesheet.get_sprite(128, 0, self.width, self.height)
    ];
    if direction == 'up' {
        self.image = up_animations[math.floor(self.animation_loop)];
        self.animation_loop += 0.5;
        if self.animation_loop >= 5 {
            self.kill();
        }
    }
    if direction == 'down' {
        self.image = down_animations[math.floor(self.animation_loop)];
        self.animation_loop += 0.5;
        if self.animation_loop >= 5 {
            self.kill();
        }
    }
    if direction == 'left' {
        self.image = left_animations[math.floor(self.animation_loop)];
        self.animation_loop += 0.5;
        if self.animation_loop >= 5 {
            self.kill();
        }
    }
    if direction == 'right' {
        self.image = right_animations[math.floor(self.animation_loop)];
        self.animation_loop += 0.5;
        if self.animation_loop >= 5 {
            self.kill();
        }
    }
}
