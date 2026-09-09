"""An exception survives a nested handler in finally; handler raises finalize."""

def fail {
    raise ValueError("original");
}

def nested {
    try {
        fail();
    } finally {
        try {
            raise TypeError("temporary");
        } except TypeError {
            print("temporary handled");
        }
        print("inner finally");
    }
}

def handler_raise {
    try {
        fail();
    } except ValueError {
        raise TypeError("replacement");
    } finally {
        print("handler finally");
    }
}

def reraising {
    try {
        fail();
    } except ValueError {
        raise;
    }
}

with entry {
    try {
        nested();
    } except ValueError {
        print("original handled");
    }
    try {
        handler_raise();
    } except TypeError {
        print("replacement handled");
    }
    try {
        reraising();
    } except ValueError {
        print("reraised");
    }
}
