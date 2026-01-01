'''Test file for .cl file serves the client module.'''

node Todo {
    has text: str;
    has done: bool = False;
}

walker create_todo {
    has text: str;

    can create with `root entry {
        new_todo = here ++> Todo(text=self.text);
        report new_todo ;
    }
}
