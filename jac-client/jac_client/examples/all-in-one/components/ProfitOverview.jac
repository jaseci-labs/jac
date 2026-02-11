# Profit Overview component - monthly profit snapshot
# Demonstrates: context usage, calculated displays, formatting
cl import from ..context.BudgetContext {
    useBudgetContext
}
cl import from ..utils.formatters { formatCurrency }

cl {
    def:pub ProfitOverview -> JsxElement {
        budget = useBudgetContext();

        businessIncome = budget["businessIncome"];
        businessExpenses = budget["businessExpenses"];
        taxReserve = budget["taxReserve"];
        netProfit = budget["netProfit"];

        return
            <div className="profit-overview">
                <h3 className="profit-title">
                    Monthly Profit Snapshot
                </h3>
                <div className="profit-breakdown">
                    <div className="profit-row income">
                        <span className="profit-label">
                            Business Income
                        </span>
                        <span className="profit-value positive">
                            +{formatCurrency(businessIncome)}
                        </span>
                    </div>
                    <div className="profit-row expense">
                        <span className="profit-label">
                            Business Expenses
                        </span>
                        <span className="profit-value negative">
                            -{formatCurrency(businessExpenses)}
                        </span>
                    </div>
                    <div className="profit-row tax">
                        <span className="profit-label">
                            Tax Reserve (20%)
                        </span>
                        <span className="profit-value negative">
                            -{formatCurrency(taxReserve)}
                        </span>
                    </div>
                    <div className="profit-row total">
                        <span className="profit-label">
                            Net Profit
                        </span>
                        <span
                            className={("profit-value bold positive")
                            if netProfit >= 0
                            else ("profit-value bold negative")}
                        >
                            {("+") if netProfit > 0 else ("")}{formatCurrency(
                                netProfit
                            )}
                        </span>
                    </div>
                </div>
            </div>;
    }
}
