"""Inventory microservice fixture.

Exposes inventory management functions and walkers.
When imported with `sv import`, these become HTTP endpoints
that the importing module calls over the network.
"""

# ============================================================================
# Data Models
# ============================================================================
obj Product {
    has sku: str,
        name: str,
        quantity: int = 0,
        price: float = 0.0;
}

obj StockInfo {
    has sku: str,
        name: str = "",
        quantity: int = 0,
        in_stock: bool = False;
}

obj Reservation {
    has success: bool,
        remaining: int = 0,
        error: str = "";
}

obj PriceInfo {
    has sku: str,
        price: float = 0.0;
}

glob _inventory: dict[str, Product] = {};

# ============================================================================
# Public Functions (exposed as API endpoints)
# ============================================================================
def:pub check_stock(sku: str) -> StockInfo {
    if sku in _inventory {
        p = _inventory[sku];
        return StockInfo(sku=sku, name=p.name, quantity=p.quantity, in_stock=p.quantity > 0);
    }
    return StockInfo(sku=sku);
}

def:pub add_product(sku: str, name: str, quantity: int, price: float) -> Product {
    p = Product(sku=sku, name=name, quantity=quantity, price=price);
    _inventory[sku] = p;
    return p;
}

def:pub reserve_stock(sku: str, quantity: int) -> Reservation {
    if sku not in _inventory {
        return Reservation(success=False, error="Product not found");
    }
    p = _inventory[sku];
    if p.quantity < quantity {
        return Reservation(success=False, error="Insufficient stock", remaining=p.quantity);
    }
    p.quantity = p.quantity - quantity;
    return Reservation(success=True, remaining=p.quantity);
}

def:pub get_price(sku: str) -> PriceInfo {
    if sku in _inventory {
        return PriceInfo(sku=sku, price=_inventory[sku].price);
    }
    return PriceInfo(sku=sku);
}

# ============================================================================
# Walkers (also exposed as endpoints)
# ============================================================================
walker:pub ListProducts {
    can enumerate with Root entry {
        products: list[Product] = [];
        for (sku, p) in _inventory.items() {
            products.append(p);
        }
        report products;
    }
}
