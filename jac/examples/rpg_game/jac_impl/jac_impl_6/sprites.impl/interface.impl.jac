impl Button.postinit{
    self.font = pygame.font.Font(GENERAL_FONT, self.fontsize);
    self.image = pygame.Surface((self.width, self.height));
    self.image.fill(self.bg);
    self.rect = self.image.get_rect();
    self.rect.x = self.x;
    self.rect.y = self.y;
    self.text = self.font.render(self.content, True, self.fg);
    self.text_rect = self.text.get_rect(center=(self.width / 2, self.width / 2));
    self.image.blit(self.text, self.text_rect);
}
# Determine if thebutton is pressed.
impl Button.is_pressed(
    pos: tuple, pressed: tuple
) -> bool {
    if self.rect.collidepoint(pos) {
        if pressed[0] {
            return True;
        }
        return False;
    }
    return False;
}
