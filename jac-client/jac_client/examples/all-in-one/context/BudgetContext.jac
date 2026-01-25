# Budget Context for global state management
# Demonstrates: createContext, useContext, Context.Provider
cl import from react {
    createContext,
    useContext
}
cl import from ..hooks.useBudget { useBudget }

cl {
    # Create the context - demonstrates glob for context
    glob:pub BudgetContext = createContext(None);

    # Provider component - wraps app and provides budget state
    def:pub BudgetProvider(children: any) -> any {
        budget = useBudget();

        return
            <BudgetContext.Provider value={budget}>
                {children}
            </BudgetContext.Provider>;
    }

    # Custom hook to access budget context
    def:pub useBudgetContext -> dict {
        context = useContext(BudgetContext);
        if context == None {
            console.error("useBudgetContext must be used within BudgetProvider");
        }
        return context;
    }
}
