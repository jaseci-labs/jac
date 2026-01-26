"""Test module for spawn operator in both standard and reverse order."""

# Server-side node and walker definitions
node TestNode {
    has value: int = 0;
}

walker test_walker {
    has message: str = "Hello from walker";

    can execute with `root entry {
        report {"result": self.message};
    }
}

walker parameterized_walker {
    has value: int;

    can execute with `root entry {
        report {"computed": self.value * 2};
    }
}

walker positional_walker {
    has label: str;
    has count: int;
    has metadata: dict = {};

    can execute with `root entry {
        report {"label": self.label, "count": self.count, "meta": self.metadata};
    }
}

# Client-side code testing both spawn orderings
cl {
    def app() -> any {
        has standardResult: any = None;
        has standardComputed: any = None;
        has reverseResult: any = None;
        has uuidResult: any = None;
        has reverseUuidResult: any = None;
        has positionalResult: any = None;
        has spreadResult: any = None;

        async can with entry {
            # Test standard spawn order: node spawn walker()
            data1 = root spawn test_walker();
            standardResult = data1;

            data2 = root spawn parameterized_walker(value=42);
            standardComputed = data2;

            # Test reverse spawn order: walker() spawn node
            data3 = test_walker(message="Reverse spawn!") spawn root;
            reverseResult = data3;

            # Test spawn with UUID string: uuid_string spawn walker()
            node_id = "550e8400-e29b-41d4-a716-446655440000";
            data4 = node_id spawn test_walker();
            uuidResult = data4;

            # Test reverse spawn with UUID string: walker() spawn uuid_string
            another_node_id = "6ba7b810-9dad-11d1-80b4-00c04fd430c8";
            data5 = parameterized_walker(value=100) spawn another_node_id;
            reverseUuidResult = data5;

            # Test positional walker arguments inferred from has fields
            data6 = node_id spawn positional_walker("Node positional", 2);
            positionalResult = data6;

            # Test **kwargs via spread when walker is on left-hand side
            extra_fields = {"metadata": {"source": "client-side"}};
            data7 = positional_walker("Spread order", 5, **extra_fields) spawn root;
            spreadResult = data7;
        }

        return
            <div>
                <h1>
                    Spawn Operator Test
                </h1>
                <h2>
                    Standard Order (node spawn walker)
                </h2>
                <div>
                    Result: {JSON.stringify(standardResult)}
                </div>
                <div>
                    Computed: {JSON.stringify(standardComputed)}
                </div>
                <h2>
                    Reverse Order (walker spawn node)
                </h2>
                <div>
                    Result: {JSON.stringify(reverseResult)}
                </div>
                <h2>
                    UUID Spawn (uuid spawn walker)
                </h2>
                <div>
                    Result: {JSON.stringify(uuidResult)}
                </div>
                <h2>
                    Reverse UUID Spawn (walker spawn uuid)
                </h2>
                <div>
                    Result: {JSON.stringify(reverseUuidResult)}
                </div>
                <h2>
                    Positional Walker Arguments
                </h2>
                <div>
                    Result: {JSON.stringify(positionalResult)}
                </div>
                <h2>
                    Spread Walker Arguments
                </h2>
                <div>
                    Result: {JSON.stringify(spreadResult)}
                </div>
            </div>;
    }
}
