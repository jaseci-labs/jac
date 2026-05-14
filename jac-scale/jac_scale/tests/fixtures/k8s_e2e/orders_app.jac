"""Orders Service - order management.

Demonstrates inter-service communication via `sv import`:
  Orders service imports functions from cart_app and calls them like
  normal functions. The compiler generates HTTP stubs; the runtime
  auto-spawns cart_app via our `ensure_sv_service` hookimpl.

Exposes public functions for order operations. Callable via:
  - HTTP: POST /api/orders/function/{name}
  - sv import: `sv import from orders_app { create_order, list_orders }`
"""

# Shared node types (all services import from the same module so the
# shared anchor store can be deserialized consistently).
import from shared.models { Order, Cart, Product, Products }

# Inter-service imports - compiler generates HTTP stubs
sv import from cart_app { view_cart, clear_cart }

glob _order_counter: int = 0;

to sv:

def:pub create_order -> dict {
    # 1. Fetch cart from cart service via sv import (HTTP under the hood)
    cart = view_cart();
    items = cart.get("items", []) if cart else [];

    if not items {
        return {"error": "Cart is empty"};
    }

    # 2. Create order locally
    global _order_counter;
    _order_counter += 1;
    order_id = f"ord_{_order_counter}";

    import from datetime { datetime, UTC }
    total: float = 0.0;
    for item in items {
        total += float(item.get("price", 0)) * int(item.get("qty", 1));
    }

    root() ++> Order(
        id=order_id,
        items=items,
        total=round(total, 2),
        status="confirmed",
        created_at=str(datetime.now(UTC))
    );

    # 3. Clear cart via sv import
    clear_cart();

    return {
        "id": order_id,
        "status": "confirmed",
        "total": round(total, 2),
        "item_count": len(items)
    };
}

def:pub list_orders -> list[dict] {
    result: list[dict] = [];
    for o in [root()-->][?:Order] {
        result.append(
            {
                "id": o.id,
                "status": o.status,
                "total": o.total,
                "item_count": len(o.items),
                "created_at": o.created_at
            }
        );
    }
    return result;
}

def:pub get_order(order_id: str) -> dict {
    for o in [root()-->][?:Order] {
        if o.id == order_id {
            return {
                "id": o.id,
                "status": o.status,
                "total": o.total,
                "items": o.items,
                "created_at": o.created_at
            };
        }
    }
    return {"error": "Order not found"};
}

def:pub cancel_order(order_id: str) -> dict {
    for o in [root()-->][?:Order] {
        if o.id == order_id {
            if o.status == "confirmed" {
                o.status = "cancelled";
                return {"id": order_id, "status": "cancelled"};
            }
            return {"error": f"Cannot cancel order in '{o.status}' status"};
        }
    }
    return {"error": "Order not found"};
}
