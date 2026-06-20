# Counter app styled with a plain CSS import.
cl import ".styles.css";

cl {
    def:pub app -> JsxElement {
        has count: int = 0;

        handleIncrement = lambda e: any { count = count + 1; };

        return
            <div className="container">
                <div className="countDisplay">{count}</div>
                <button onClick={handleIncrement}>+</button>
            </div>;
    }
}
