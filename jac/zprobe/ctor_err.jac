obj HA {
    has x: int = 0;
    def init(y: int) { self.x = y * 2; }
}
obj HC(HA) { has z: int = 0; }
obj HD(HA) { def postinit { self.x = 1; } }
