"""Cart Service - shopping cart management.

Exposes public functions for cart operations. Callable via:
  - HTTP: POST /api/cart/function/{name}
  - sv import: `sv import from cart_app { view_cart, add_to_cart, clear_cart }`
"""

import from shared.models { Cart, Product, Products, Order }

def _get_or_create_cart -> Cart {
    carts = [root()-->][?:Cart];
    if carts {
        return carts[0];
    }
    return (root() ++> Cart())[0];
}

to sv:

def:pub add_to_cart(
    product_id: str, product_name: str = "", price: float = 0.0, qty: int = 1
) -> dict {
    cart = _get_or_create_cart();
    # Check if product already in cart
    for item in cart.items {
        if item.get("product_id") == product_id {
            item["qty"] = item.get("qty", 0) + qty;
            return {"action": "updated", "product_id": product_id, "qty": item["qty"]};
        }
    }
    cart.items.append(
        {
            "product_id": product_id,
            "product_name": product_name,
            "price": price,
            "qty": qty
        }
    );
    return {"action": "added", "product_id": product_id, "qty": qty};
}

def:pub view_cart -> dict {
    carts = [root()-->][?:Cart];
    if not carts {
        return {"items": [], "total": 0, "item_count": 0};
    }
    cart: Cart = carts[0];
    total: float = 0.0;
    display_items: list[dict] = [];
    for item in cart.items {
        line_total: float = float(item.get("price", 0)) * int(item.get("qty", 1));
        display_items.append(
            {
                "product_id": item.get("product_id", ""),
                "product_name": item.get("product_name", ""),
                "price": item.get("price", 0),
                "qty": item.get("qty", 1),
                "line_total": round(line_total, 2)
            }
        );
        total += line_total;
    }
    return {
        "items": display_items,
        "total": round(total, 2),
        "item_count": len(cart.items)
    };
}

def:pub remove_from_cart(product_id: str) -> dict {
    carts = [root()-->][?:Cart];
    if not carts {
        return {"error": "Cart not found"};
    }
    cart: Cart = carts[0];
    new_items: list[dict] = [];
    for item in cart.items {
        if item.get("product_id") != product_id {
            new_items.append(item);
        }
    }
    cart.items = new_items;
    return {"action": "removed", "product_id": product_id};
}

def:pub clear_cart -> dict {
    carts = [root()-->][?:Cart];
    if not carts {
        return {"action": "cleared", "items_removed": 0};
    }
    cart: Cart = carts[0];
    cleared: int = len(cart.items);
    cart.items = [];
    return {"action": "cleared", "items_removed": cleared};
}
