
# Pages
cl import from react {useEffect}
cl import from .store {useCounterStore}

cl {
    def CounterValue() -> any {
        count = useCounterStore(lambda state: any { return state.count; });
        console.log("Rendering CounterValue with count:");
        return <div style={{"fontSize": "48px", "fontWeight": "700", "color": "#2563eb"}}>{count}</div>;
    }

    def CounterControls() -> any {
        console.log("Rendering CounterControls");
        increment = useCounterStore(lambda state: any { return state.increment; });
        decrement = useCounterStore(lambda state: any { return state.decrement; });
        reset = useCounterStore(lambda state: any { return state.reset; });

        return <div style={{"display": "flex", "gap": "12px", "flexWrap": "wrap"}}>
            <button onClick={lambda -> None { decrement(); }} style={{"padding": "10px 18px", "borderRadius": "8px", "border": "none", "backgroundColor": "#f87171", "color": "white", "fontSize": "16px"}}>− Step</button>
            <button onClick={lambda -> None { increment(); }} style={{"padding": "10px 18px", "borderRadius": "8px", "border": "none", "backgroundColor": "#22c55e", "color": "white", "fontSize": "16px"}}>+ Step</button>
            <button onClick={lambda -> None { reset(); }} style={{"padding": "10px 18px", "borderRadius": "8px", "border": "1px solid #e2e8f0", "backgroundColor": "white", "color": "#0f172a", "fontSize": "16px"}}>Reset</button>
        </div>;
    }

    def StepAdjuster() -> any {
        step = useCounterStore(lambda state: any { return state.step; });
        console.log("Rendering StepAdjuster with step:");
        setStep = useCounterStore(lambda state: any { return state.setStep; });

        return <label style={{"display": "flex", "flexDirection": "column", "gap": "6px", "fontSize": "14px", "color": "#475569"}}>
            Step size
            <input
                type="number"
                min="1"
                value={step}
                onChange={lambda e: any -> None {
                    nextStep = e.target.valueAsNumber or 1;
                    setStep(nextStep and nextStep > 0 and nextStep or 1);
                }}
                style={{"padding": "8px", "borderRadius": "8px", "border": "1px solid #cbd5f5", "fontSize": "16px"}}
            />
        </label>;
    }

    def StatePreview() -> any {
        state = useCounterStore();

        console.log("Rendering StatePreview with state:");

        return <pre style={{"backgroundColor": "#0f172a", "color": "#e2e8f0", "padding": "12px", "borderRadius": "10px", "fontSize": "14px", "width": "100%", "overflowX": "auto"}}>
            {JSON.stringify(state, None, 2)}
        </pre>;
    }

    def app() -> any {
        console.log("Rendering app component");
        count = useCounterStore(lambda state: any { return state.count; });
        useEffect(lambda -> None {
            console.log("Count changed to", count);
        }, [count]);

        return <main style={{"minHeight": "100vh", "display": "flex", "alignItems": "center", "justifyContent": "center", "backgroundColor": "#f8fafc", "padding": "40px"}}>
            <div style={{"width": "100%", "maxWidth": "520px", "backgroundColor": "white", "borderRadius": "24px", "boxShadow": "0 20px 45px rgba(15,23,42,0.12)", "padding": "32px", "display": "flex", "flexDirection": "column", "gap": "24px"}}>
                <div>
                    <p style={{"textTransform": "uppercase", "color": "#94a3b8", "letterSpacing": "0.2em", "margin": "0 0 6px"}}>Zustand demo</p>
                    <h1 style={{"margin": "0", "fontSize": "32px", "color": "#0f172a"}}>Shared state from a Jac view</h1>
                    <p style={{"marginTop": "8px", "color": "#475569"}}>Multiple components hook into the same store and stay in sync with zero prop drilling.</p>
                </div>

                <CounterValue />
                <CounterControls />
                <StepAdjuster />

                <div>
                    <p style={{"margin": "0 0 6px", "color": "#475569", "fontWeight": "600"}}>Live store snapshot</p>
                    <StatePreview />
                </div>
            </div>
        </main>;
    }
}
