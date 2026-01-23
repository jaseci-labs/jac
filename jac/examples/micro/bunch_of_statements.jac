"""A mega example of a bunch of statements and expressions."""

"""
This function takes a list of numbers and returns a
generator of even numbers.
"""
def example_function(numbers: list[int]) -> int {
    # multi string
    print(
        "this function processes the provided list."
        "It then yields the even numbers."
        "It will stop once an even number greater than 20 is found."
    );

    # assignments and expressions
    counter = 0;
    even_numbers = [];

    # for loop and comprehension
    for number in [i + 1 for i in numbers] {
        # walrus operation (assignment expressions, appears Python 3.8 and later, and Jac!)
        # if (result := number % 2) == 0 {  # Python compaitble version
        result = 100;
        result %= 2;
        if result == 0 {  # Jac improved version

            even_numbers.append(number);
            counter += 1;
            # assert
            assert counter <= len(numbers) , "Counter should not exceed the length of the list";
            # yield
            yield f"Even number {counter}: {number}";  # f-string
            # if-elif-else
            if number > 20 {
                print("Encountered even number greater than 20, breaking loop");
                break;  # break
            } elif number == 20 {
                print("Encountered 20, skipping this number");
                continue;  # continue
            }
        } else {
            print(f"{number} is not an even number");
        }
    }

    # while loop
    while len(even_numbers) > 0 {
        # delete
        del even_numbers[0];
    }

    print("All done!");
}

# testing the function

# iteration for loop
with entry {
    for i = 1 to i < 5 by i += 1 {
        for result in example_function([1, 2, 3, 4, 5, 21, 22, 23, 24]) {
            print(result);
        }
    }
}
