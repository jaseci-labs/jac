# Match singleton patterns - Pattern matching in match statements

with entry {
    # Match True singleton
    data = True;
    match data {
        case True:
            print("Matched the singleton True");
        case False:
            print("Matched the singleton False");
        case None:
            print("Matched the singleton None");
    }

    # Match False singleton
    flag = False;
    match flag {
        case True:
            print("True");
        case False:
            print("Matched the singleton False");
        case None:
            print("None");
    }

    # Match None singleton
    val = None;
    match val {
        case True:
            print("True");
        case False:
            print("False");
        case None:
            print("Matched the singleton None");
    }
}
