node test_node {
    has value: int;
}

walker test_walker {
    has visited_nodes: list = [],
        entry_count: int = 0,
        exit_count: int = 0;

    can traverse with Root entry {
        visit [-->](?:test_node);
    }

    can log_entry with entry {
        print("Entering at the beginning of walker: ", here);
        self.entry_count += 1;
    }

    can log_visit with test_node exit {
        print("Visiting node : ", here);
        self.visited_nodes.append(here);
    }

    can log_exit with exit {
        print("Exiting at the end of walker: ", here);
        self.exit_count += 1;
    }
}

with entry {
    for i in range(10) {
        root ++> (next := test_node(value=i));
    }
}

glob wlk_obj = root spawn test_walker();

with entry {
    print(wlk_obj);
}
