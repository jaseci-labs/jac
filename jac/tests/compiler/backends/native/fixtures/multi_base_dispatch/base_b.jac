obj Right {
    has right_seed: int = 2;
    has right_value: int { getter; }

    def right_name -> int {
        return 40;
    }
}

impl Right.right_value.getter -> int {
    return self.right_seed * 5;
}

node RightNode {
    has right_seed: int = 2,
        right_items: list[int] = [];

    has right_value: int { getter; }

    def right_name -> int {
        return 40;
    }
}

impl RightNode.right_value.getter -> int {
    return self.right_seed * 5 + len(self.right_items);
}
