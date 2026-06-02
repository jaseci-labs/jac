node MyNode {}

glob my_node: MyNode = MyNode();

walker GoodWalker {
    can visit with Root entry {
        print("GoodWalker: ok");
    }
}

walker BadWalker {
    can visit with root entry {
        print("should not reach here");
    }
}

walker BadNodeInstance {
    can visit with my_node entry {
        print("should not reach here");
    }
}

with entry {
    root spawn GoodWalker();

    try {
        root spawn BadWalker();
    } except TypeError as e {
        print(f"BadWalker: {e}");
    }

    try {
        root spawn BadNodeInstance();
    } except TypeError as e {
        print(f"BadNodeInstance: {e}");
    }
}
