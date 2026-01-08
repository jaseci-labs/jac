
#
# Basic backend walkers
#
node Todo {
    has text: str,
        done: bool = False;
}

walker create_todo {
    has text: str;

    can create with `root entry {
        new_todo = here ++> Todo(text=self.text);
        report new_todo ;
    }
}

walker ping_server {
    can ping with `root entry {
        report "pong from backend!" ;
    }
}

walker get_server_message {
    can info with `root entry {
        report "hello from a basic walker!" ;
    }
}
