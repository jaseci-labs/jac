def switch_case(fruit: str) {
    switch fruit {
        case "apple":
            print("Matched case for value: apple");
            break;

        case "banana":

        case "orange":
            print("Matched case for value: banana, orange");

        case "grape":
            print("Matched case for value: grape");

        case "kiwi":
            print("Matched case for value: kiwi");

        case "Berry" | "Cherry":
            print("Matched case for value: Berry or Cherry");

        default:
            print("No match found for value: " + str(fruit));

    }
}

with entry {
    switch_case("apple");
    switch_case("banana");
    switch_case("mango");
}
