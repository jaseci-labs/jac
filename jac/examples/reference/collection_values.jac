with entry {
    squares = {num: num ** 2  for num in range(1, 6)};
    even_squares_set = {num ** 2  for num in range(1, 11) if num % 2 == 0};
    squares_generator = (num ** 2  for num in range(1, 6));
    squares_list = [num ** 2 for num in squares_generator if num != 9];

    print(
        "\n".join(
            [str(squares), str(even_squares_set), str(squares_list)]
        )
    );

    print(
        {"a": "b", "c": "d"}, # Dictionary
        {"a"}, # Set
        ("a", ), # Tuple
        ['a'] # List
    );
}
