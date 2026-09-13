def empty {}

def takes_argument(flag: bool) {}

obj Worker {
    def perform {}
}

def forwards_empty -> None {
    return empty();
}

def forwards_argument -> None {
    return takes_argument(True);
}

def forwards_alias -> None {
    original = takes_argument;
    return original(True);
}

def forwards_method(worker: Worker) -> None {
    return worker.perform();
}
