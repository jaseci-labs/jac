# Budget Planner Page
# Main application page with budget tracking features

# Local JAC file imports
cl import from ..context.BudgetContext { useBudgetContext }
cl import from ..components.Header { Header }
cl import from ..components.Summary { Summary }
cl import from ..components.ProfitOverview { ProfitOverview }
cl import from ..components.TransactionForm { TransactionForm }
cl import from ..components.TransactionList { TransactionList }
cl import from ..components.CategoryFilter { CategoryFilter }
cl import from ..constants.categories { CATEGORY_COLORS }

# cl import from "..components.PieChart.tsx" { PieChart }
cl def:pub BudgetPlanner -> JsxElement {
    [filter, setFilter] = useState("ALL");
    budget = useBudgetContext();

    # Filter transactions based on selected category
    filtered = budget["transactions"];
    if filter != "ALL" {
        filtered = [
            tx
            for tx in filtered
            if tx["category"] == filter
        ];
    }

    # Sort by date (newest first)
    sorted = filtered.slice().sort(
        lambda a: dict , b: dict  -> int { return Reflect.construct(Date, [b["date"]]).getTime() - Reflect.construct(
            Date, [a["date"]]
        ).getTime(); }
    );

    # Prepare chart data with colors
    chartData = [
        {
            "name": item["name"],
            "value": item["value"],
            "color": CATEGORY_COLORS[item["name"]]
        } for item in budget["expensesByCategory"]
    ];

    return
        <div className="app-container">
            <Header/>
            <main className="main-content">
                <div className="left-panel">
                    <Summary/>
                    <ProfitOverview/>
                    <TransactionForm/>
                    <CategoryFilter selectedCategory={filter} onSelect={setFilter}/>
                    <TransactionList
                        transactions={sorted}
                        onDelete={budget["deleteTransaction"]}
                    />
                </div>
                <div className="right-panel"></div>
            </main>
        </div>;
}
# <PieChart
#     data={chartData}
#     title="Expense Breakdown"
#     colors={CATEGORY_COLORS}
# />
