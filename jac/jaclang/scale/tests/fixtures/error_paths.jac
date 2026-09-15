walker:pub Boom {
    can go with Root entry {
        raise ValueError("boom");
    }
}

def:pub boom_fn -> int {
    raise ValueError("boom");
}

@restspec(protocol=APIProtocol.WEBHOOK)
walker BoomHook {
    can go with Root entry {
        raise ValueError("boom");
    }
}
