def switch_case(Num: int) {
    switch Num {
        case 2:

        case 3:

        case 10:
            print("Matched case for value: 2, 3, 10");

        case 15:

        case 20:
            print("Matched case for value: 15, 20");
            break;

        case 25:

        case None:
            print("Matched case for value: 25 or None");

        default:
            print("No match found for value: " + str(Num));

    }
}

with entry {
    switch_case(3);
    switch_case(15);
    switch_case(25);
}
