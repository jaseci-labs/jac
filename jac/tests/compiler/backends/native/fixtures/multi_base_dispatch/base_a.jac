obj Left {
    has left_seed: int = 1;
    has left_value: int { getter; }

    def left_name -> int {
        return 10;
    }

    def left_extra -> int {
        return 20;
    }
}

impl Left.left_value.getter -> int {
    return self.left_seed * 3;
}

node LeftNode {
    has left_seed: int = 1;
    has left_value: int { getter; }

    def left_name -> int {
        return 10;
    }
}

impl LeftNode.left_value.getter -> int {
    return self.left_seed * 3;
}
