"""Example of simple walker walking nodes."""

node Item {
    has value: int = 1;
}


edge Checking {}


walker Creator {
    has count: int = 0;

    can create with `root | Item entry {
        here ++> Item();
        self.count += 1;
        if self.count < 10 {
            visit [-->];
        }
    }
}


walker Walk {
    has count: int = 0;
    has value: int = 0;

    can skip_root with `root entry {
        visit [-->];
    }

    can step with Item entry {
        here.value = self.count;
        self.count += 1;
        visit [-->] else {
            print(f"Final Value: {here.value - 1}");
            "Done walking." |> print;
            disengage;
        }
        f"Value: {here.value - 1}" |> print;
    }
}


def test_run {
    root spawn Creator();
    Walk() spawn root;
}


with entry {
    test_run();
}


def generate_joke -> dict[str, str] by llm();
