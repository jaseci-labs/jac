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
