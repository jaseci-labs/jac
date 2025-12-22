node test_node {
    has value: int;

    can log_entry with entry {
        print(f">>> Some Walker entered the node: ", self);
    }

    can log_test_walker_entry with test_walker entry {
        print(f">>> {visitor} entered the node {visitor}");
        visitor.callable();
    }

    can log_test_walker_exit with test_walker exit {
        print(f"<<< {visitor} exited the node {self}");
    }

    can log_exit with exit {
        print(f"<<< Some Walker exited the node {self}");
    }

    def callable {
        print(f"===== Callable on {self}");
    }
}

walker test_walker {
    has walker_id: int;

    can traverse with `root entry {
        for i in range(2) {
            root ++> (next := test_node(value=i));
        }
        visit [-->](`?test_node);
    }

    can log_entry with entry {
        print(f"--- Entering at the beginning of walker {self}");
    }

    can log_visit_entry with test_node entry {
        print(f"--- Visiting {here} : Entry");
        here.callable();
    }

    can log_visit_exit with test_node exit {
        print(f"--- Visiting {here} : Exit");
    }

    can log_exit with exit {
        print("--- Exiting at the end of walker {self}");
    }

    def callable {
        print(f"===== Callable on {self}");
    }
}

glob wlk_obj = root spawn test_walker(walker_id=381);  # print(wlk_obj);
