
# Pages
cl import from react { useEffect }
cl import from ".components/Button.tsx" { Button }

cl {
    def:pub app -> any {
        has count: int = 0;
        useEffect(lambda   -> None{ console.log("Count: ", count);} , [count]);
        return <div
            style={{padding: "2rem", fontFamily: "Arial, sans-serif"}}
        >
            <h1>
                Hello, World!
            </h1>
            <p>
                Count: {count}
            </p>
            <div
                style={{display: "flex", gap: "1rem", marginTop: "1rem"}}
            >
                <Button
                    label="Increment"
                    onClick={lambda   -> None{ count = count + 1;} }
                    variant="primary"
                />
                <Button
                    label="Reset"
                    onClick={lambda   -> None{ count = 0;} }
                    variant="secondary"
                />
            </div>
        </div>;
    }
}
