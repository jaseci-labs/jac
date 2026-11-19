obj DataError(Exception) {
    has path: str = "",
        problem: str = "";

    def __str__ -> str;
}

def commit;

def jobj(name: str) -> any;

def allroots -> list[Root];

def grant(n: Node, level: AccessLevel = AccessLevel.READ);

def remove(n: Node);
