# Pages
cl import from .styled {
    Container,
    Card,
    Title,
    Divider,
    CounterSection,
    Label,
    CountDisplay,
    ButtonGroup,
    Button,
    Hint
}

cl {
    def:pub app -> any {
        has count: int = 0;

        can with count entry {
            console.log("Count changed: ", count);
        }

        handleIncrement = lambda e: any  -> None { count = count + 1;};

        handleDecrement = lambda e: any  -> None { count = count - 1;};

        handleReset = lambda e: any  -> None { count = 0;};

        return
            <Container>
                <Card>
                    <Title>
                        Counter Application
                    </Title>
                    <Divider></Divider>
                    <CounterSection>
                        <Label>
                            Current Count
                        </Label>
                        <CountDisplay count={count}>
                            {count}
                        </CountDisplay>
                    </CounterSection>
                    <Divider></Divider>
                    <ButtonGroup>
                        <Button bgColor="#ef4444" onClick={handleDecrement}>
                            -
                        </Button>
                        <Button bgColor="#6b7280" onClick={handleReset}>
                            ↻
                        </Button>
                        <Button bgColor="#22c55e" onClick={handleIncrement}>
                            +
                        </Button>
                    </ButtonGroup>
                    <Hint>
                        Click the buttons to increment, decrement, or reset the counter
                    </Hint>
                </Card>
            </Container>;
    }
}
