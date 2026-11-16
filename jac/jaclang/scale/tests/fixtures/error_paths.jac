walker:pub Boom {
    can go with Root entry {
        raise ValueError("boom");
    }
}

def:pub boom_fn -> int {
    raise ValueError("boom");
}

@restspec(protocol=APIProtocol.WEBHOOK)
walker:protect BoomHook {
    can go with Root entry {
        raise ValueError("boom");
    }
}

walker:protect NamesMissingUser {
    can go with Root entry {
        raise ValueError("User not found");
    }
}

def:protect names_missing_user -> int {
    raise ValueError("User not found");
}

node Note {}

walker:protect MakeNote {
    can go with Root entry {
        note = Note();
        here ++> note;
        report str(note.__jac__.ensure_id());
    }
}

walker:pub Pong {
    can go with Root entry {
        report "pong";
    }
}
