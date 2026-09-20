glob dropped: int = 0,
     continued: int = 0;

obj Resource {
    def drop {
        dropped += 1;
    }
}

obj Request {
    def run -> int abst;
}

obj Failure(Request) {
    def run -> int {
        held = Resource();
        raise ValueError("virtual failure");
    }
}

def invoke(request: Request) -> int {
    result = request.run();
    continued += 1;
    return result;
}

def check -> bool {
    dropped = 0;
    continued = 0;
    try {
        invoke(Failure());
    } except ValueError {
        return dropped == 1 and continued == 0;
    }
    return False;
}
