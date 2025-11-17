# Cart slice - manages shopping cart state
cl {
    def createCartSlice(setState: any, getState: any, store: any) -> dict {
        return {
            "items": [],
            "total": 0,

            "addItem": lambda item: dict -> None {
                setState(lambda state: any -> dict {
                    newItems = state.items.concat([item]);
                    newTotal = state.total + (item.price or 0);
                    return {
                        **state,
                        "items": newItems,
                        "total": newTotal
                    };
                });
            },

            "removeItem": lambda itemId: str -> None {
                setState(lambda state: any -> dict {
                    itemToRemove = state.items.find(lambda i: any -> bool {
                        return i.id == itemId;
                    });

                    newItems = state.items.filter(lambda i: any -> bool {
                        return i.id != itemId;
                    });

                    priceToSubtract = itemToRemove and itemToRemove.price or 0;

                    return {
                        **state,
                        "items": newItems,
                        "total": state.total - priceToSubtract
                    };
                });
            },

            "clearCart": lambda -> None {
                setState(lambda state: any -> dict {
                    return {**state, "items": [], "total": 0};
                });
            }
        };
    }
}
