obj Name {
    has value: str;

    def change(new_value: str) {
        self.value = new_value;
        return self.value;
    }
}

obj User {
    has name: Name;

    def greet {
        return "Hello, " + self.name.value;
    }
}

with entry {
    user = User(Name("Alice"));
    ghost = None;
    print(ghost?.name?.value);
    print(user?.name?.value);
    print(user?.item?.value);
    print(user?.name?.items);
    mylist = [1, 2, 3];
    print(mylist?[2]);
    mlist = None;
    print(mlist?[0]);
}
