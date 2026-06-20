# Counter app styled with styled-components.
cl import from .styled { Container, CountDisplay, Button }

cl {
    def:pub app -> JsxElement {
        has count: int = 0;

        handleIncrement = lambda e: any { count = count + 1; };

        return
            <Container>
                <CountDisplay count={count}>{count}</CountDisplay>
                <Button bgColor="#22c55e" onClick={handleIncrement}>+</Button>
            </Container>;
    }
}
