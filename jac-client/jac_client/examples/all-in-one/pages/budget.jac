cl {
    import from .budget_planner_ui { BudgetPlanner as BudgetPlannerUI }
    import from ..context.BudgetContext { BudgetProvider }

    def:pub page -> JsxElement {
        return
            <BudgetProvider>
                <BudgetPlannerUI/>
            </BudgetProvider>;
    }
}
