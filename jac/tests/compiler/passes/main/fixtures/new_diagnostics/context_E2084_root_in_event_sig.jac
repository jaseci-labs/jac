"""Fixture for E2084: 'root' (value) used where 'Root' (type) is required in event signature."""

walker ListTodos {
    can collect with root entry {  # <-- Error E2084: 'root' is a value, not a type
        print("I am here");
        report "I have worked";
    }
}

walker CorrectWalker {
    can collect with Root entry {  # <-- OK: 'Root' is the correct type
        print("correct");
    }
}
