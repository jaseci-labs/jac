# Pages
cl import from react { useEffect }
cl import ".styles.scss";

cl {
    def:pub app -> any {
        has count: int = 0;

        useEffect(lambda   -> None{ console.log("Count changed: ", count);} , [count]);

        handleIncrement = lambda  e: any  -> None{ count = count + 1;} ;

        handleDecrement = lambda  e: any  -> None{ count = count - 1;} ;

        handleReset = lambda  e: any  -> None{ count = 0;} ;

        countClass = "countDisplay " + (
            "positive" if count > 0 else "negative" if count < 0 else "zero"
        );

        return <div className="container">
            <div className="card">
                <h1 className="title">
                    Counter Application
                </h1>
                <div className="divider"></div>
                <div className="counterSection">
                    <div className="label">
                        Current Count
                    </div>
                    <div
                        className={countClass}
                    >
                        {count}
                    </div>
                </div>
                <div className="divider"></div>
                <div className="buttonGroup">
                    <button
                        className="btn btnDecrement"
                        onClick={handleDecrement}
                    >
                        -
                    </button>
                    <button
                        className="btn btnReset"
                        onClick={handleReset}
                    >
                        ↻
                    </button>
                    <button
                        className="btn btnIncrement"
                        onClick={handleIncrement}
                    >
                        +
                    </button>
                </div>
                <div className="hint">
                    Click the buttons to increment, decrement, or reset the counter
                </div>
            </div>
        </div>;
    }
}
