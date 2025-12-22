# Raise Statements
def raise_exception {
    raise ValueError("error message") ;
}

def raise_with_expression {
    x = 10;
    raise RuntimeError(f"value is {x}") ;
}

def raise_from_exception {
    try {
        x = 5 / 0;
    } except ZeroDivisionError as e {
        raise RuntimeError("division failed") from e ;
    }
}

def bare_raise {
    try {
        raise ValueError("original") ;
    } except ValueError {
        print("caught, re-raising");
        raise ;
    }
}

def conditional_raise(value: int) {
    if value < 0 {
        raise ValueError("must be non-negative") ;
    }
    if value > 100 {
        raise ValueError("must be <= 100") ;
    }
}

# Basic raise
with entry {
    try {
        raise_exception();
    } except ValueError as e {
        print(f"caught: {e}");
    }

    # Raise with expression
    try {
        raise_with_expression();
    } except RuntimeError as e {
        print(f"caught: {e}");
    }

    # Raise from (exception chaining)
    try {
        raise_from_exception();
    } except RuntimeError as e {
        print(f"caught: {e}");
    }

    # Bare raise (re-raise)
    try {
        bare_raise();
    } except ValueError as e {
        print(f"re-raised: {e}");
    }

    # Conditional raise
    try {
        conditional_raise(-5);
    } except ValueError as e {
        print(f"caught: {e}");
    }

    try {
        conditional_raise(150);
    } except ValueError as e {
        print(f"caught: {e}");
    }

    # Raise without except
    try {
        conditional_raise(50);
        print("no error");
    } except ValueError {
        print("unexpected");
    }
}
