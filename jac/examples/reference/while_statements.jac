# While Statements

# Basic while loop
glob x = 0;

with entry {
    while x < 5 {
        print(x);
        x += 1;
    }
}

# While with complex condition
glob a = 0,
     b = 10;

with entry {
    while a < 5 and b > 5 {
        print(f"a={a}, b={b}");
        a += 1;
        b -= 1;
    }
}

# While with else clause (executes when condition becomes false)
glob count = 0;

with entry {
    while count < 3 {
        print(count);
        count += 1;
    } else {
        print("completed");
    }
}

# While with break (else clause skipped)
glob i = 0;

with entry {
    while i < 10 {
        if i == 3 {
            break;
        }
        print(i);
        i += 1;
    } else {
        print("not reached");
    }
}

# While with continue
glob num = 0;

with entry {
    while num < 5 {
        num += 1;
        if num % 2 == 0 {
            continue;
        }
        print(num);
    }
}

# Infinite loop with break
glob counter = 0;

with entry {
    while True {
        print(counter);
        counter += 1;
        if counter >= 3 {
            break;
        }
    }
}

# Nested while loops
glob outer = 0;

with entry {
    while outer < 2 {
        inner = 0;
        while inner < 2 {
            print(f"{outer},{inner}");
            inner += 1;
        }
        outer += 1;
    }
}
