# If Statements

# Basic if statement
glob x = 10;

with entry {
    if x > 5 {
        print("x is greater than 5");
    }
}

# If-else statement
glob age = 18;

with entry {
    if age >= 18 {
        print("adult");
    } else {
        print("minor");
    }
}

# If-elif-else chain
glob score = 85;

with entry {
    if score >= 90 {
        print("A");
    } elif score >= 80 {
        print("B");
    } elif score >= 70 {
        print("C");
    } else {
        print("F");
    }
}

# Multiple elif chains
glob value = 15;

with entry {
    if value < 5 {
        print("very low");
    } elif value < 10 {
        print("low");
    } elif value < 15 {
        print("medium");
    } elif value < 20 {
        print("high");
    } else {
        print("very high");
    }
}

# Nested if statements
glob a = 15,
     b = 20;

with entry {
    if a > 10 {
        print("a > 10");
        if b > 15 {
            print("b > 15");
            if a + b > 30 {
                print("a + b > 30");
            }
        }
    }

    # Complex boolean expressions
    if a > 5 and b > 10 {
        print("both conditions true");
    }

    if a > 100 or b > 15 {
        print("at least one true");
    }

    if not (a > 50) {
        print("negation true");
    }

    if (a > 5 and b > 10) or (a < 20) {
        print("complex expression true");
    }
}

# Chained comparisons
glob temp = 25;

with entry {
    if 20 <= temp <= 30 {
        print("comfortable temperature");
    }
}

# Membership tests
glob fruits = ["apple", "banana"];

with entry {
    if "apple" in fruits {
        print("apple found");
    }

    if "grape" not in fruits {
        print("grape not found");
    }
}

# Identity tests
glob val = None;

with entry {
    if val is None {
        print("val is None");
    }

    if val is not None {
        print("val is not None");
    } else {
        print("val is None");
    }
}
