node City {
    has name: str = "";
}

glob users: list[dict[str, any]] = [];

walker Tourist {
    can travel with City entry {
        def foo(a: int) {}
        x = lambda (a: int, b: int) { b + a; };
        y = lambda { 567; };
        sorted_users = sorted(
            users, key=lambda (x: dict[str, any]) { x["email"]; }, reverse=True
        );
    }

    def visit_city(c: City) {
        print("Visiting", c.name);
    }
}
