"""Main entry point for the Jac client application."""

# Client-side imports
cl import from react { useState, useEffect }
cl import from ".components/Button.tsx" { Button }

# Client-side component
cl {
    def:pub app() -> any {
        [count, setCount] = useState(0);

        useEffect(lambda -> None {
            console.log("Count updated:", count);
        }, [count]);

        return <div style={{padding: "2rem", fontFamily: "Arial, sans-serif"}}>
            <h1>Hello, World!</h1>
            <p>Count: {count}</p>
            <div style={{display: "flex", gap: "1rem", marginTop: "1rem"}}>
                <Button
                    label="Increment"
                    onClick={lambda -> None { setCount(count + 1); }}
                    variant="primary"
                />
                <Button
                    label="Reset"
                    onClick={lambda -> None { setCount(0); }}
                    variant="secondary"
                />
            </div>
        </div>;
    }
}

