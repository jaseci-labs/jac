node Item {
    has label: str = "";
}

walker:protect make_item {
    can run with Root entry {
        report root ++> Item(label="one");
    }
}

walker:protect find_item {
    has item_id: str = "";

    can run with Root entry {
        target = jobj(self.item_id);
        report {"is_item": isinstance(target, Item)};
    }
}
