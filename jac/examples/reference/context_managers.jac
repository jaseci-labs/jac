# Context Managers

# Basic with statement with as binding
with entry {
    with open(__file__, 'r') as f {
        print("file opened");
    }

    # Multiple context managers
    with open(__file__, 'r') as f1, open(__file__, 'r') as f2 {
        print("multiple files");
    }
}

# With statement without as binding
class Printer {
    def __enter__(self: Printer) -> Printer {
        print("entering");
        return self;
    }

    def __exit__(
        self: Printer, exc_type: object, exc_val: object, exc_tb: object
    ) -> None {
        print("exiting");
    }
}

with entry {
    with Printer() {
        print("inside");
    }

    # With as binding
    with Printer() as p {
        print("with binding");
    }

    # Nested with statements
    with Printer() as p1 {
        with Printer() as p2 {
            print("nested");
        }
    }
}

# Async with statement
async def test_async_with {
    class AsyncContext {
        async def __aenter__(self: AsyncContext) -> AsyncContext {
            print("async entering");
            return self;
        }

        async def __aexit__(
            self: AsyncContext, exc_type: object, exc_val: object, exc_tb: object
        ) -> None {
            print("async exiting");
        }
    }

    async with AsyncContext() as ac {
        print("async inside");
    }
}
