node MyNode {
    has result: str = "";

    can process with MyWalker entry {
        self.result = "processed";
        return "bad";  # W2014: should not return a value from an ability
    }

    can process_ok with MyWalker entry {
        self.result = "ok";
        return;  # bare return is fine
    }
}

walker MyWalker {
    has data: str = "";

    can visit_node with MyNode entry {
        self.data = "visited";
        return 42;  # W2014: should not return a value from an ability
    }

    def helper -> str {
        return "this is fine";  # regular def, no warning
    }
}
