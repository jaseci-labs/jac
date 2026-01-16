# Pages
cl import from react { useEffect }
cl {
    def:pub app -> any {
        has count: int = 0;
        useEffect(lambda   -> None{ console.log("Count: ", count);} , [count]);
        return <div>
            <h1>
                Hello, World!
            </h1>
            <p>
                Count: {count}
            </p>
            <button
                onClick={lambda  e: any  -> None{ count = count + 1;} }
            >
                Increment
            </button>
        </div>;
    }
}
