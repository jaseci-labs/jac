# Custom hook for budget operations
# Demonstrates: custom hooks, useState, array methods
cl import from react {
    useCallback,
    useMemo
}

cl {
    # Main budget management hook
    def:pub useBudget -> dict {
        # Simple useState - no complex localStorage hook
        [transactions, setTransactions] = useState([]);

        # Add a new transaction
        def addTransaction(
            description: str,
            amount: float,
            category: str,
            txType: str,
            isBusiness: bool,
            clientName: str
        ) -> None {
            newTx = {
                "id": Date.now().toString(),
                "description": description,
                "amount": amount,
                "category": category,
                "type": txType,
                "date": Reflect.construct(Date, []).toISOString(),
                "isBusinessTransaction": isBusiness,
                "clientName": clientName if clientName != "" else None
            };
            setTransactions(transactions.concat([newTx]));
        }

        # Delete a transaction by ID
        def deleteTransaction(id: str) -> None {
            filtered = transactions.filter(
                lambda tx: dict  -> bool { return tx["id"] != id; }
            );
            setTransactions(filtered);
        }

        # Calculate totals
        totalIncome = 0.0;
        totalExpenses = 0.0;
        for tx in transactions {
            if tx["type"] == "income" {
                totalIncome = totalIncome + tx["amount"];
            } else {
                totalExpenses = totalExpenses + tx["amount"];
            }
        }
        balance = totalIncome - totalExpenses;

        # Calculate business/personal breakdown
        businessIncome = 0.0;
        businessExpenses = 0.0;
        personalIncome = 0.0;
        personalExpenses = 0.0;

        for tx in transactions {
            isBusiness = tx["isBusinessTransaction"] || false;
            amount = tx["amount"];

            if tx["type"] == "income" {
                if isBusiness {
                    businessIncome = businessIncome + amount;
                } else {
                    personalIncome = personalIncome + amount;
                }
            } else {
                if isBusiness {
                    businessExpenses = businessExpenses + amount;
                } else {
                    personalExpenses = personalExpenses + amount;
                }
            }
        }

        # Tax calculations
        TAX_RATE = 0.20;
        taxReserve = businessIncome * TAX_RATE;
        netProfit = businessIncome - businessExpenses - taxReserve;

        # Get expense breakdown by category (for chart)
        def getExpensesByCategory -> list {
            categoryTotals = {};
            for tx in transactions {
                if tx["type"] == "expense" {
                    cat = tx["category"];
                    if categoryTotals[cat] {
                        categoryTotals[cat] = categoryTotals[cat] + tx["amount"];
                    } else {
                        categoryTotals[cat] = tx["amount"];
                    }
                }
            }
            result = [];
            for key in Object.keys(categoryTotals) {
                result = result.concat([{"name": key, "value": categoryTotals[key]}]);
            }
            return result;
        }

        return {
            "transactions": transactions,
            "addTransaction": addTransaction,
            "deleteTransaction": deleteTransaction,
            "totalIncome": totalIncome,
            "totalExpenses": totalExpenses,
            "balance": balance,
            "expensesByCategory": getExpensesByCategory(),
            "businessIncome": businessIncome,
            "businessExpenses": businessExpenses,
            "personalIncome": personalIncome,
            "personalExpenses": personalExpenses,
            "taxReserve": taxReserve,
            "netProfit": netProfit
        };
    }
}
