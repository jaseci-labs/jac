obj Name {
    has value: str;

    def change(new_value: str) -> str {
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
    print(mylist?[10]);
    print(mylist?[-1]);
    print(mylist?[-10]);
    print(mylist?[1:3]);
    print(mylist?[10:20]);

    none_list = None;
    print(none_list?[0]);
    print(none_list?[1:3]);
}
