obj Rock {
    has pellets:list;

    def count_pellets() -> int {
        return self.pellets.length();
    }
}

with entry {
    rock = Rock(pellets=[1, 2, 3]);
    print("Number of pellets: " + rock.count_pellets().to_string());
}