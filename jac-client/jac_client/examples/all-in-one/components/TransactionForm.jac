# Transaction form component
# Demonstrates: form handling, useState, events, select options
cl import from ..context.BudgetContext { useBudgetContext }
cl import from ..constants.categories { CATEGORIES, CATEGORY_LABELS }
cl import from ..constants.clients { CLIENTS }

cl {
    def:pub TransactionForm -> JsxElement {
        has description: str = "",
            amount: str = "",
            category: str = "OTHER",
            txType: str = "expense",
            isBusiness: Any = false,
            clientName: str = "";

        budget = useBudgetContext();

        def handleSubmit(e: Any) -> None {
            e.preventDefault();

            # Validate inputs
            trimmedDesc = description.strip();
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
            description = "";
            amount = "";
            category = "OTHER";
            isBusiness = false;
            clientName = "";
        }

        # Filter categories based on type (income only has INCOME category)
        availableCategories = [
            cat
            for cat in CATEGORIES
            if (cat == "INCOME" if txType == "income" else cat != "INCOME")
        ];

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
                            onClick={lambda -> any { txType = "expense";}}
                        >
                            Expense
                        </button>
                        <button
                            type="button"
                            className={("toggle-btn active income")
                                if txType == "income"
                                else ("toggle-btn")}
                            onClick={lambda -> any { txType = "income";}}
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
                            onClick={lambda -> any { isBusiness = true;}}
                        >
                            Business
                        </button>
                        <button
                            type="button"
                            className={("toggle-btn active")
                                if not isBusiness
                                else ("toggle-btn")}
                            onClick={lambda -> any { isBusiness = false;}}
                        >
                            Personal
                        </button>
                    </div>
                </div>
                <div className="form-row">
                    <div className="form-group">
                        <label htmlFor="description">Description</label>
                        <input
                            id="description"
                            type="text"
                            value={description}
                            onChange={lambda e: Any { description = e.target.value;}}
                            placeholder="Enter description..."
                            className="form-input"
                        />
                    </div>
                    <div className="form-group">
                        <label htmlFor="amount">Amount</label>
                        <input
                            id="amount"
                            type="number"
                            value={amount}
                            onChange={lambda e: Any { amount = e.target.value;}}
                            placeholder="0.00"
                            min="0"
                            step="0.01"
                            className="form-input"
                        />
                    </div>
                    <div className="form-group">
                        <label htmlFor="category">Category</label>
                        <select
                            id="category"
                            value={category}
                            onChange={lambda e: Any { category = e.target.value;}}
                            className="form-select"
                        >
                            {[
                                <option key={cat} value={cat}>
                                    {CATEGORY_LABELS[cat]}
                                </option> for cat in availableCategories
                            ]}
                        </select>
                    </div>
                    {showClientDropdown
                    and <div className="form-group">
                        <label htmlFor="client">Client</label>
                        <select
                            id="client"
                            value={clientName}
                            onChange={lambda e: Any { clientName = e.target.value;}}
                            className="form-select"
                        >
                            <option value="">Select Client (Optional)</option>
                            {[
                                <option key={client} value={client}>{client}</option>
                                for client in CLIENTS
                            ]}
                        </select>
                    </div>}
                    <div className="form-group">
                        <label>Action</label>
                        <button type="submit" className="submit-btn">
                            Add{(txType[0].upper() + txType[1:])}
                        </button>
                    </div>
                </div>
            </form>;
    }
}
