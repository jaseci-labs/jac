# Transaction list component
# Demonstrates: rendering lists with map, passing props to child components
cl import from .TransactionItem {
    TransactionItem
}

cl {
    # Props: transactions list and delete handler
    def:pub TransactionList(transactions: list, onDelete: any) -> JsxElement {
        if transactions.length == 0 {
            return
                <div className="empty-state">
                    <p>
                        No transactions yet.
                    </p>
                    <p>
                        Add your first income or expense above!
                    </p>
                </div>;
        }

        return
            <div className="transaction-list">
                <h3 className="list-title">
                    Transactions ({transactions.length})
                </h3>
                {transactions.map(
                    lambda tx: dict  -> JsxElement { return
                        <TransactionItem
                            key={tx["id"]}
                            id={tx["id"]}
                            description={tx["description"]}
                            amount={tx["amount"]}
                            category={tx["category"]}
                            txType={tx["type"]}
                            date={tx["date"]}
                            isBusiness={tx["isBusinessTransaction"] || false}
                            clientName={tx["clientName"] || None}
                            onDelete={onDelete}
                        />; }
                )}
            </div>;
    }
}
