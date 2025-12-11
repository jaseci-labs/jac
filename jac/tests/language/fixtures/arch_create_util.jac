node UtilityNode {
    has data: int;

    can display_data with entry {
        print("UtilityNode Data:", f'{self.data}');
    }
}
