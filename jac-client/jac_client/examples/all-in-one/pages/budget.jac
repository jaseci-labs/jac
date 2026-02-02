cl {
    import from .budget_planner_ui { BudgetPlanner as BudgetPlannerUI }
    import from ..context.BudgetContext { BudgetProvider }

    def:pub page -> any {
        return
            <BudgetProvider>
                <BudgetPlannerUI />
            </BudgetProvider>;
    }
}
