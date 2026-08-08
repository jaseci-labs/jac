"""Compose Android demo — native Compose surface → Jetpack Compose.

    jac setup android
    jac build --client android --platform android
    jac start --client android

Uses the native Compose vocabulary (Column, Text, Button, Modifier) — not DOM/Tailwind.
"""

walker:pub greet {
    has name: str = "friend";

    can greet with Root entry {
        report f"Hello, {self.name}!";
    }
}

def:pub app -> Composable {
    has count: int = 0,
        name: str = "",
        greeting: str = "Tap Say hello";

    return
        <Column modifier={Modifier.padding(24.dp)}>
            <Text style={Typography.titleLarge}>"Jac → Jetpack Compose"</Text>
            <Column modifier={Modifier.padding(16.dp)}>
                <Text style={Typography.titleMedium}>"Counter"</Text>
                <Text>{count}</Text>
                <Row>
                    <Button onClick={lambda { count = count + 1; }}>
                        <Text>"Increment"</Text>
                    </Button>
                    <Button onClick={lambda { count = 0; }}>
                        <Text>"Reset"</Text>
                    </Button>
                </Row>
            </Column>
            <Column modifier={Modifier.padding(16.dp)}>
                <Text>"Greeting (typed RPC)"</Text>
                <OutlinedTextField
                    value={name}
                    onValueChange={lambda (v: str) { name = v; }}
                    placeholder="Your name"
                />
                <Button
                    onClick={lambda {
                        next_greeting = "Empty response";
                        try {
                            result = root spawn greet(name=name);
                            if result.reports.len > 0 {
                                next_greeting = result.reports[0];
                            }
                        } except Exception {
                            next_greeting = "Request failed — is jac serve running?";
                        }
                        greeting = next_greeting;
                    }}
                >
                    <Text>"Say hello"</Text>
                </Button>
                <Text>{greeting}</Text>
            </Column>
        </Column>;
}
