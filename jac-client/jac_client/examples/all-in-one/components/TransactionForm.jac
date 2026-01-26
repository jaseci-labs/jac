# Transaction form component
# Demonstrates: form handling, useState, events, select options
cl import from ..context.BudgetContext {
    useBudgetContext
}
cl import from ..constants.categories { CATEGORIES, CATEGORY_LABELS }
cl import from ..constants.clients { CLIENTS }

cl {
    def:pub TransactionForm -> any {
        [description, setDescription] = useState("");
        [amount, setAmount] = useState("");
        [category, setCategory] = useState("OTHER");
        [txType, setTxType] = useState("expense");
        [isBusiness, setIsBusiness] = useState(false);
        [clientName, setClientName] = useState("");
        budget = useBudgetContext();

        def handleSubmit(e: any) -> None {
            e.preventDefault();

            # Validate inputs
            trimmedDesc = description.trim();
            if trimmedDesc == "" or amount == "" {
                return;
            }

            parsedAmount = parseFloat(amount);
            if isNaN(parsedAmount) or parsedAmount <= 0 {
                return;
            }

            # Add the transaction
            budget["addTransaction"](
                trimmedDesc, parsedAmount, category, txType, isBusiness, clientName
            );

            # Reset form
            setDescription("");
            setAmount("");
            setCategory("OTHER");
            setIsBusiness(false);
            setClientName("");
        }

        # Filter categories based on type (income only has INCOME category)
        availableCategories = CATEGORIES.filter(
            lambda cat: str  -> bool { if txType == "income" {
                return cat == "INCOME";
            }return cat != "INCOME"; }
        );

        # Show client dropdown only for business income
        showClientDropdown = txType == "income" and isBusiness;

        return
            <form className="transaction-form" onSubmit={handleSubmit}>
                <div className="form-row">
                    <div className="form-group type-toggle">
                        <button
                            type="button"
                            className={("toggle-btn active")
                            if txType == "expense"
                            else ("toggle-btn")}
                            onClick={lambda : setTxType("expense")}
                        >
                            Expense
                        </button>
                        <button
                            type="button"
                            className={("toggle-btn active income")
                            if txType == "income"
                            else ("toggle-btn")}
                            onClick={lambda : setTxType("income")}
                        >
                            Income
                        </button>
                    </div>
                    <div className="form-group business-toggle">
                        <button
                            type="button"
                            className={("toggle-btn active")
                            if isBusiness
                            else ("toggle-btn")}
                            onClick={lambda : setIsBusiness(true)}
                        >
                            Business
                        </button>
                        <button
                            type="button"
                            className={("toggle-btn active")
                            if not isBusiness
                            else ("toggle-btn")}
                            onClick={lambda : setIsBusiness(false)}
                        >
                            Personal
                        </button>
                    </div>
                </div>
                <div className="form-row">
                    <div className="form-group">
                        <label htmlFor="description">
                            Description
                        </label>
                        <input
                            id="description"
                            type="text"
                            value={description}
                            onChange={lambda e: any  -> None { setDescription(
                                e.target.value
                            );}}
                            placeholder="Enter description..."
                            className="form-input"
                        />
                    </div>
                    <div className="form-group">
                        <label htmlFor="amount">
                            Amount
                        </label>
                        <input
                            id="amount"
                            type="number"
                            value={amount}
                            onChange={lambda e: any  -> None { setAmount(
                                e.target.value
                            );}}
                            placeholder="0.00"
                            min="0"
                            step="0.01"
                            className="form-input"
                        />
                    </div>
                    <div className="form-group">
                        <label htmlFor="category">
                            Category
                        </label>
                        <select
                            id="category"
                            value={category}
                            onChange={lambda e: any  -> None { setCategory(
                                e.target.value
                            );}}
                            className="form-select"
                        >
                            {availableCategories.map(
                                lambda cat: str  -> any { return
                                    <option key={cat} value={cat}>
                                        {CATEGORY_LABELS[cat]}
                                    </option>; }
                            )}
                        </select>
                    </div>
                    {showClientDropdown
                    and <div className="form-group">
                        <label htmlFor="client">
                            Client
                        </label>
                        <select
                            id="client"
                            value={clientName}
                            onChange={lambda e: any  -> None { setClientName(
                                e.target.value
                            );}}
                            className="form-select"
                        >
                            <option value="">
                                Select Client (Optional)
                            </option>
                            {CLIENTS.map(
                                lambda client: str  -> any { return
                                    <option key={client} value={client}>
                                        {client}
                                    </option>; }
                            )}
                        </select>
                    </div>}
                    <div className="form-group">
                        <label>
                            Action
                        </label>
                        <button type="submit" className="submit-btn">
                            Add {(txType[0].toUpperCase() + txType.slice(1))}
                        </button>
                    </div>
                </div>
            </form>;
    }
}
