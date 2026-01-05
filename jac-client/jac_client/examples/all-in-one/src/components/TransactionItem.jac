# Single transaction item component
# Demonstrates: NEW PROPS PATTERN (direct parameters, NOT props dict)

cl import from ..utils.formatters { formatCurrency, formatDate }
cl import from ..constants.categories { CATEGORY_COLORS, CATEGORY_LABELS }

cl {
    # NEW WAY: Direct parameters instead of props: dict
    def:pub TransactionItem(
        id: str,
        description: str,
        amount: float,
        category: str,
        txType: str,
        date: str,
        isBusiness: bool,
        clientName: any,
        onDelete: any
    ) -> any {
        isIncome = txType == "income";
        color = CATEGORY_COLORS[category];
        label = CATEGORY_LABELS[category];

        return <div className="transaction-item">
            <div className="tx-left">
                <span
                    className="tx-category"
                    style={{"backgroundColor": color}}
                >
                    {label}
                </span>
                <div className="tx-details">
                    <span className="tx-description">
                        {description}
                        {(clientName != None and isIncome) and <span className="tx-client"> • {clientName}</span>}
                    </span>
                    <span className="tx-date">{formatDate(date)}</span>
                </div>
            </div>

            <div className="tx-right">
                <span className={("tx-amount income") if isIncome else ("tx-amount expense")}>
                    {("+") if isIncome else ("-")}{formatCurrency(amount)}
                </span>
                <button
                    className="delete-btn"
                    onClick={lambda:onDelete(id)}
                    title="Delete transaction"
                >
                    X
                </button>
            </div>
        </div>;
    }
}
