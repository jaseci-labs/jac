impl TextEvent.init(text: str = "") {
    self.kind = "text";
    self.text = text;
}


impl KeyEvent.init(key: str = "") {
    self.kind = "key";
    self.key = key;
}


impl PasteEvent.init(text: str = "") {
    self.kind = "paste";
    self.text = text;
}


impl ResizeEvent.init(width: int = 0, height: int = 0) {
    self.kind = "resize";
    self.width = width;
    self.height = height;
}


impl MouseEvent.init(
    button: int = 0,
    x: int = 0,
    y: int = 0,
    pressed: bool = False,
    motion: bool = False,
) {
    self.kind = "mouse";
    self.button = button;
    self.x = x;
    self.y = y;
    self.pressed = pressed;
    self.motion = motion;
}


impl StreamChunkEvent.init(text: str = "") {
    self.kind = "stream";
    self.text = text;
}

impl EofEvent.init {
    self.kind = "eof";
}


impl InterruptEvent.init {
    self.kind = "interrupt";
}
