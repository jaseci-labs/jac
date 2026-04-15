"""Order microservice fixture.

Imports inventory_service with `sv` keyword, meaning it treats
inventory_service as a separate microservice. The compiler generates
HTTP client stubs so calls to check_stock, reserve_stock, etc.
go over the network rather than being in-process.
"""

sv import from inventory_service {
    check_stock, reserve_stock, get_price,
    StockInfo, Reservation, PriceInfo
}

# ============================================================================
# Data Models
# ============================================================================
obj OrderItem {
    has sku: str,
        quantity: int,
        unit_price: float = 0.0;
}

obj OrderResult {
    has success: bool,
        order_id: str = "",
        total: float = 0.0,
        status: str = "",
        item_count: int = 0,
        error: str = "";
}

obj OrderInfo {
    has order_id: str,
        total: float = 0.0,
        status: str = "",
        item_count: int = 0;
}

obj FeasibilityResult {
    has sku: str,
        requested: int,
        available: int = 0,
        feasible: bool = False;
}

obj OrderRecord {
    has items: list[OrderItem],
        total: float = 0.0;
}

glob _orders: dict[str, OrderRecord] = {};
glob _state: dict[str, int] = {"next_id": 1};

# ============================================================================
# Public Functions
# ============================================================================
"""Create an order after validating stock via inventory_service."""
def:pub create_order(items: list[dict]) -> OrderResult {
    order_items: list[OrderItem] = [];
    total: float = 0.0;

    # Validate stock and get prices from inventory microservice
    for item in items {
        sku: str = item["sku"];
        qty: int = item["quantity"];

        # These calls go over HTTP to inventory_service (sv import)
        stock: StockInfo = check_stock(sku);
        if not stock.in_stock or stock.quantity < qty {
            return OrderResult(
                success=False,
                error=f"Insufficient stock for {sku}"
            );
        }

        price: PriceInfo = get_price(sku);

        # Reserve the stock in inventory microservice
        reservation: Reservation = reserve_stock(sku, qty);
        if not reservation.success {
            return OrderResult(success=False, error=reservation.error);
        }

        order_items.append(OrderItem(sku=sku, quantity=qty, unit_price=price.price));
        total = total + (price.price * qty);
    }

    order_id = f"ORD-{_state['next_id']}";
    _state["next_id"] = _state["next_id"] + 1;
    _orders[order_id] = OrderRecord(items=order_items, total=total);

    return OrderResult(
        success=True,
        order_id=order_id,
        total=total,
        status="confirmed",
        item_count=len(order_items)
    );
}

def:pub get_order(order_id: str) -> OrderInfo {
    if order_id in _orders {
        rec = _orders[order_id];
        return OrderInfo(
            order_id=order_id,
            total=rec.total,
            status="confirmed",
            item_count=len(rec.items)
        );
    }
    return OrderInfo(order_id=order_id, status="not_found");
}

# ============================================================================
# Walkers
# ============================================================================
walker:pub CheckOrderFeasibility {
    has sku: str;
    has quantity: int = 1;

    can check with Root entry {
        # Cross-service call to inventory microservice
        stock: StockInfo = check_stock(self.sku);
        feasible = stock.in_stock and stock.quantity >= self.quantity;
        report FeasibilityResult(
            sku=self.sku,
            requested=self.quantity,
            available=stock.quantity,
            feasible=feasible
        );
    }
}
