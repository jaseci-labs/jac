import from .base_a { Left }
import from .base_b { Right }

obj Both(Left, Right) {
    has bonus: int = 7;

    def right_name -> int {
        return 400 + self.bonus;
    }
}
