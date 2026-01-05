impl Spritesheet.postinit(file: str) {
    self.sheet = pygame.image.load(self.file).convert();
}

impl Spritesheet.get_sprite(x: int, y: int, width: int, height: int) -> pygame.Surface {
    sprite = pygame.Surface([width, height]);
    sprite.blit(self.sheet, (0, 0), (x, y, width, height));
    sprite.set_colorkey(BLACK);
    return sprite;
}
