# Pages
cl import from react { useEffect }
# Import image using the @jac-client/assets alias
cl import from "@jac-client/assets/burger.png" {
    default as burgerImage
}

cl {
    def:pub app -> any {
        has count: int = 0;
        useEffect(lambda   -> None{ console.log("Count: ", count);} , [count]);
        return <div
            style={{
                padding: "20px",
                textAlign: "center",
                fontFamily: "Arial, sans-serif"
            }}
        >
            <h1>
                🍔 Import Alias Example
            </h1>
            <p
                style={{color: "#666", marginBottom: "20px"}}
            >
                Using
                <code>
                    @jac-client/assets
                </code>
                alias to import assets
            </p>
            <img
                src={burgerImage}
                alt="Delicious Burger"
                style={{
                    width: "200px",
                    height: "auto",
                    margin: "20px 0",
                    borderRadius: "10px",
                    boxShadow: "0 4px 8px rgba(0,0,0,0.2)"
                }}
            />
            <p
                style={{fontSize: "18px", margin: "20px 0"}}
            >
                You've clicked the burger
                <strong>
                    {count}
                </strong>
                times!
            </p>
            <button
                onClick={lambda  e: any  -> None{ count = count + 1;} }
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
            <div
                style={{
                    marginTop: "30px",
                    padding: "15px",
                    backgroundColor: "#f5f5f5",
                    borderRadius: "5px",
                    fontSize: "12px",
                    textAlign: "left",
                    maxWidth: "600px",
                    margin: "30px auto"
                }}
            >
                <strong>
                    How it works:
                </strong>
                <ul
                    style={{marginTop: "10px", paddingLeft: "20px"}}
                >
                    <li>
                        Import using:
                        <code>
                            cl import from '@jac-client/assets/burger.png'
                        </code>
                    </li>
                    <li>
                        Vite processes the import and generates optimized URLs
                    </li>
                    <li>
                        Assets are automatically copied from
                        <code>
                            assets/
                        </code>
                        to
                        <code>
                            compiled/assets/
                        </code>
                        during build
                    </li>
                    <li>
                        Automatic hash generation for cache busting
                    </li>
                </ul>
            </div>
        </div>;
    }
}
