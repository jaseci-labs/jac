# Counter app styled with JS style objects.
cl import from .styles { default as styles }

cl {
    def:pub app -> JsxElement {
        has count: int = 0;

        handleIncrement = lambda e: any { count = count + 1; };

        return
            <div style={styles.container}>
                <div style={styles.countDisplay}>{count}</div>
                <button onClick={handleIncrement}>+</button>
            </div>;
    }
}
