# Names and References

# self - instance reference
obj Counter {
    has count: int = 0;

    def increment {
        self.count += 1;
        print(self.count);
    }
}

# super - parent reference
obj Animal {
    def speak {
        print("animal sound");
    }
}

obj Dog(Animal) {
    def speak {
        super.speak();
        print("woof");
    }
}

# here - current node reference
node Task {
    has name: str;
}

walker TaskWalker {
    can process with Task entry {
        print(f"at {here.name}");
        visit [-->];
    }
}

# visitor - current walker reference
node Interactive {
    has visitor_name: str = "none";

    can track with TaskWalker entry {
        self.visitor_name = visitor.__class__.__name__;
        print(f"visited by {self.visitor_name}");
    }
}

# root - root node reference
walker RootWalker {
    can start with `root entry {
        print(f"at root: {root}");
        print(f"here is root: {here is root}");
        visit [-->];
    }

    can at_task with Task entry {
        print(f"root is: {root}");
    }
}

# init and postinit
obj Configured {
    has value: int;
    has doubled: int = 0;

    def init(value: int) {
        self.value = value;
        self.postinit();
    }

    def postinit {
        self.doubled = self.value * 2;
    }
}

with entry {
    # Test self
    c = Counter();
    c.increment();
    c.increment();

    # Test super
    d = Dog();
    d.speak();

    # Test here and visitor
    task = Task(name="test");
    inter = Interactive();
    root ++> task;
    task ++> inter;
    root spawn TaskWalker();

    # Test root
    root spawn RootWalker();

    # Test init/postinit
    cfg = Configured(value=10);
    print(f"value={cfg.value}, doubled={cfg.doubled}");
}
