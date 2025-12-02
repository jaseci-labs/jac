import random;
import from typing { Tuple }

obj Button {
    def is_pressed(pos: tuple, pressed: str) -> bool {
        return True;
    }
}

def ttt()  -> int {
    b = Button();
    a = random.randint(1, 10);
    b.is_pressed((1, 2, 3), a);
    return 0;
}
