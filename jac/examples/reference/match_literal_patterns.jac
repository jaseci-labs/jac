# Match literal patterns - Pattern matching in match statements

with entry {
    # Integer literals
    num = 89;
    match num {
        case 89:
            print("Matched integer 89");
        case 0:
            print("Matched zero");
        case 100:
            print("Matched 100");
    }

    # Float literals
    pi = 3.14;
    match pi {
        case 3.14:
            print("Matched float 3.14");
        case 2.71:
            print("Matched e");
    }

    # String literals
    text = "hello";
    match text {
        case "hello":
            print("Matched string 'hello'");
        case "world":
            print("Matched string 'world'");
    }

    # Boolean literals (note: use singleton patterns for booleans)
    flag = True;
    match flag {
        case True:
            print("Matched boolean True");
        case False:
            print("Matched boolean False");
    }

    # None literal (note: use singleton patterns for None)
    val = None;
    match val {
        case None:
            print("Matched None");
    }
}
