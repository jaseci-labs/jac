node MyNode {}

with entry {
    first_tier = [MyNode() for i in range(2)];
    second_tier = [MyNode() for i in range(2)];

    root ++> first_tier;
    first_tier ++> second_tier;

    end_tier = MyNode();
    second_tier ++> end_tier;
}
