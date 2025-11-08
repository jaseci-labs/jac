with entry {
    data = True;
    match True {

        # MatchSingleton
        case True:
            print("Matched the singleton True.");
        case None:
            print("Matched the singleton None.");
    }
}
