node MyNode {}

glob first_tier = [MyNode() for i in range(2)],
     second_tier = [MyNode() for i in range(2)];

with entry {
    root ++> first_tier;
    first_tier ++> second_tier;
}

glob end_tier = MyNode();

with entry {
    second_tier ++> end_tier;
}
