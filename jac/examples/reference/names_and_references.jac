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
# Note: In 'obj', methods have implicit self (doesn't appear in parameters).
# In 'class', methods require explicit self with type annotation: def init(self: MyClass, ...)
# This example uses 'obj' with implicit self.
obj Configured {
    has value: int,
        doubled: int = 0;

    def init(value: int) {
        self.value = value;
        self.postinit();
    }

    def postinit {
        self.doubled = self.value * 2;
    }
}

# Test self
glob c = Counter();

with entry {
    c.increment();
    c.increment();
}

# Test super
glob d = Dog();

with entry {
    d.speak();
}

# Test here and visitor
glob task = Task(name="test"),
     inter = Interactive();

with entry {
    root ++> task;
    task ++> inter;
    root spawn TaskWalker();

    # Test root
    root spawn RootWalker();
}

# Test init/postinit
glob cfg = Configured(value=10);

with entry {
    print(f"value={cfg.value}, doubled={cfg.doubled}");
}
