impl Block.postinit{
    self._groups = (self.game.all_sprites, self.game.blocks);
    pygame.sprite.Sprite.init(self, self._groups);
    self.x *= TILESIZE;
    self.y *= TILESIZE;
    self.image = self.game.terrain_spritesheet.get_sprite(
        960, 448, self.width, self.height
    );
    self.rect = self.image.get_rect();
    self.rect.x = self.x;
    self.rect.y = self.y;
}

impl Ground.postinit(game: None, x: int, y: int) {
    self._groups = self.game.all_sprites;
    pygame.sprite.Sprite.init(self, self._groups);
    self.x *= TILESIZE;
    self.y *= TILESIZE;
    self.image = self.game.terrain_spritesheet.get_sprite(
        64, 352, self.width, self.height
    );
    self.rect = self.image.get_rect();
    self.rect.x = self.x;
    self.rect.y = self.y;
}
