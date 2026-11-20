glob ESC: str = "\x1b",
     BRACKETED_PASTE_START: str = "\x1b[200~",
     BRACKETED_PASTE_END: str = "\x1b[201~";


obj HostEvent {
    has kind: str = "";
}


obj TextEvent(HostEvent) {
    has text: str = "";

    def init(text: str = "");
}


obj KeyEvent(HostEvent) {
    has key: str = "";

    def init(key: str = "");
}


obj PasteEvent(HostEvent) {
    has text: str = "";

    def init(text: str = "");
}


obj ResizeEvent(HostEvent) {
    has width: int = 0,
        height: int = 0;

    def init(width: int = 0, height: int = 0);
}


obj MouseEvent(HostEvent) {
    has button: int = 0,
        x: int = 0,
        y: int = 0,
        pressed: bool = False,
        motion: bool = False;

    def init(
        button: int = 0,
        x: int = 0,
        y: int = 0,
        pressed: bool = False,
        motion: bool = False,
    );
}


obj StreamChunkEvent(HostEvent) {
    has text: str = "";

    def init(text: str = "");
}

obj EofEvent(HostEvent) {
    def init;
}


obj InterruptEvent(HostEvent) {
    def init;
}
