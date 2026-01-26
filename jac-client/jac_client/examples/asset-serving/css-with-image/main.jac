# Pages
cl import ".styles.css";

cl {
    def:pub app -> any {
        has count: int = 0;

        can with count entry {
            console.log("Count: ", count);
        }

        return
            <div
                style={{
                    padding: "20px",
                    textAlign: "center",
                    fontFamily: "Arial, sans-serif"
                }}
            >
                <h1>
                    🍔 Burger Counter App
                </h1>
                <img
                    src="/static/assets/burger.png"
                    alt="Delicious Burger"
                    style={{
                        width: "200px",
                        height: "auto",
                        margin: "20px 0",
                        borderRadius: "10px",
                        boxShadow: "0 4px 8px rgba(0,0,0,0.2)"
                    }}
                />
                <p style={{fontSize: "18px", margin: "20px 0"}}>
                    You've clicked the burger
                    <strong>
                        {count}
                    </strong>
                    times!
                </p>
                <button
                    onClick={lambda e: any  -> None { count = count + 1;}}
                    style={{
                        padding: "10px 20px",
                        fontSize: "16px",
                        backgroundColor: "#ff6b35",
                        color: "white",
                        border: "none",
                        borderRadius: "5px",
                        cursor: "pointer",
                        boxShadow: "0 2px 4px rgba(0,0,0,0.2)"
                    }}
                >
                    Click the Burger! 🍔
                </button>
                <h2 style={{marginTop: "40px", marginBottom: "20px"}}>
                    CSS Asset Examples
                </h2>
                <div className="container">
                    <h3
                        style={{
                            color: "white",
                            textShadow: "2px 2px 4px rgba(0,0,0,0.5)"
                        }}
                    >
                        Background Image Example
                    </h3>
                    <p
                        style={{
                            color: "white",
                            textShadow: "2px 2px 4px rgba(0,0,0,0.5)"
                        }}
                    >
                        This container uses the burger image as a background via CSS
                    </p>
                </div>
                <div className="card">
                    <h3>
                        Image in Card
                    </h3>
                    <img
                        src="/static/assets/burger.png"
                        alt="Burger in Card"
                        className="burgerImage"
                    />
                    <p style={{marginTop: "15px", color: "#666"}}>
                        This image is displayed within a styled card using CSS classes
                    </p>
                </div>
            </div>;
    }
}
