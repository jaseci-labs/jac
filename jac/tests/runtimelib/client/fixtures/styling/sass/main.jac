# Counter app styled with a Sass (.scss) import.
cl import ".styles.scss";

cl {
    def:pub app -> JsxElement {
        has count: int = 0;

        handleIncrement = lambda e: any { count = count + 1; };

        return
            <div className="container">
                <div className="countDisplay">{count}</div>
                <button className="btn" onClick={handleIncrement}>+</button>
            </div>;
    }
}
