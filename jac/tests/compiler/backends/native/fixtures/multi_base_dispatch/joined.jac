import from .base_a { Left, LeftNode }
import from .base_b { Right, RightNode }

obj Both(Left, Right) {
    has bonus: int = 7;

    def right_name -> int {
        return 400 + self.bonus;
    }
}

node BothNode(LeftNode, RightNode) {
    has extra: int = 9;

    def right_name -> int {
        return 800 + self.extra;
    }
}
