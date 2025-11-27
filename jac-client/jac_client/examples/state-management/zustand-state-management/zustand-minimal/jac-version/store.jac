# store.jac
cl import from zustand { create }

cl {

    let counterStore = create(lambda setState: any -> dict {
        return {
            "count": 0,
            "step": 1,

            "increment": lambda -> None {
                setState(lambda state: any -> dict {
                    return {"count": state.count + state.step};
                });
            },


            "decrement": lambda -> None {
                setState(lambda state: any -> dict {
                    return {"count": state.count - state.step};
                });
            },

            "setStep": lambda nextStep: any -> None {
                safeStep = (Number.isFinite(nextStep) and nextStep > 0) and nextStep or 1;
                setState({"step": safeStep});
            },

            "reset": lambda -> None {
                setState({"count": 0, "step": 1});
            }
        };
    });

    def useCounterStore(selector: any = None) -> any {
        console.log("useCounterStore called");
        if selector {

            return counterStore(selector);
        }
        return counterStore();
    }


}
