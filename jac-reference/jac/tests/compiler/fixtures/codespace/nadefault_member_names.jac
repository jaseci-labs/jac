import from nadefault_member_names_graph { Room, carve }

with entry {
    print("windows:", carve(Room(id=1), Room(id=2)));
}
