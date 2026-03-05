obj Name {
    has first_name: str,
        last_name: str;
}

obj Person {
    has name: Name;

    def init {  #No parameters
        self.nickname = "NoNick";
    }
}

glob a = Person(name=Name(first_name="Bob", last_name="Brown"));# Error: named arg to parameterless init
glob b = Person('Jac');# Error: positional arg to parameterless init
glob c = Person();# OK: no arguments
