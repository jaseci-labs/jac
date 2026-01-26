# Pages
cl import from .styles { default as styles }

cl {
    def:pub app -> any {
        has count: int = 0;

        can with count entry {
            console.log("Count changed: ", count);
        }

        handleIncrement = lambda e: any  -> None { count = count + 1;};

        handleDecrement = lambda e: any  -> None { count = count - 1;};

        handleReset = lambda e: any  -> None { count = 0;};

        countStyle = styles.countDisplayZero
        if count == 0
        else (
            styles.countDisplayPositive if count > 0 else styles.countDisplayNegative
        );

        return
            <div style={styles.container}>
                <div style={styles.card}>
                    <h1 style={styles.title}>
                        Counter Application
                    </h1>
                    <div style={styles.divider}></div>
                    <div style={styles.counterSection}>
                        <div style={styles.label}>
                            Current Count
                        </div>
                        <div style={countStyle}>
                            {count}
                        </div>
                    </div>
                    <div style={styles.divider}></div>
                    <div style={styles.buttonGroup}>
                        <button
                            style={styles.buttonDecrement}
                            onClick={handleDecrement}
                        >
                            -
                        </button>
                        <button style={styles.buttonReset} onClick={handleReset}>
                            ↻
                        </button>
                        <button
                            style={styles.buttonIncrement}
                            onClick={handleIncrement}
                        >
                            +
                        </button>
                    </div>
                    <div style={styles.hint}>
                        Click the buttons to increment, decrement, or reset the counter
                    </div>
                </div>
            </div>;
    }
}
