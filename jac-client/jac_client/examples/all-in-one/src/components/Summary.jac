# Summary component - displays budget totals with business/personal breakdown
# Demonstrates: context usage, conditional rendering, ternary operator, 6-card layout

cl import from ..context.BudgetContext { useBudgetContext }
cl import from ..utils.formatters { formatCurrency }

cl {
    def:pub Summary() -> any {
        budget = useBudgetContext();

        # Business/Personal breakdown
        businessIncome = budget["businessIncome"];
        businessExpenses = budget["businessExpenses"];
        personalIncome = budget["personalIncome"];
        personalExpenses = budget["personalExpenses"];
        taxReserve = budget["taxReserve"];
        netProfit = budget["netProfit"];

        return <div className="summary">
            <div className="summary-card business-income">
                <span className="summary-label">Business Income</span>
                <span className="summary-value">{formatCurrency(businessIncome)}</span>
            </div>

            <div className="summary-card business-expenses">
                <span className="summary-label">Business Expenses</span>
                <span className="summary-value">{formatCurrency(businessExpenses)}</span>
            </div>

            <div className="summary-card personal-income">
                <span className="summary-label">Personal Income</span>
                <span className="summary-value">{formatCurrency(personalIncome)}</span>
            </div>

            <div className="summary-card personal-expenses">
                <span className="summary-label">Personal Expenses</span>
                <span className="summary-value">{formatCurrency(personalExpenses)}</span>
            </div>

            <div className="summary-card tax-reserve">
                <span className="summary-label">Tax Reserve (20%)</span>
                <span className="summary-value">{formatCurrency(taxReserve)}</span>
            </div>

            <div className={("summary-card net-profit positive") if netProfit >= 0 else ("summary-card net-profit negative")}>
                <span className="summary-label">Net Profit</span>
                <span className="summary-value">
                    {("+") if netProfit > 0 else ("")}{formatCurrency(netProfit)}
                </span>
            </div>
        </div>;
    }
}
