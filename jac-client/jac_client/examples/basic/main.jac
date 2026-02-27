# Pages
cl {
    def:pub app -> JsxElement {
        has count: int = 0;

        can with count entry {
            print("Count: ", count);
        }

        return
            <div>
                <h1>
                    Hello, World!
                </h1>
                <p>
                    Count:{count}
                </p>
                <button onClick={lambda e: any  -> None { count = count + 1;}}>
                    Increment
                </button>
            </div>;
    }
}
