
# Pages
cl import from react {useState, useEffect}
cl {
    def app() -> any {
        let [count, setCount] = useState(0);
        useEffect(lambda -> None {
            console.log("Count: ", count);
        }, [count]);
        return <div>
            <h1>Hello, World!</h1>
            <p>Count: {count}</p>
            <button onClick={lambda e: any ->  None {setCount(count + 1);}}>Increment</button>
        </div>;
    }
}
