"""Fixture: Bidirectional typed object passing between CL and SV.

Tests the full round-trip: CL sends typed objects to SV,
SV transforms them and returns different typed objects back.
"""

obj CartItem {
    has product_id: str,
        name: str,
        quantity: int,
        price: float;
}

obj OrderSummary {
    has order_id: str,
        items: list[CartItem],
        total: float,
        tax: float,
        status: str = "pending";
}

obj ShippingInfo {
    has address: str,
        city: str,
        method: str = "standard";
}

def:pub place_order(items: list[CartItem], shipping: ShippingInfo) -> OrderSummary {
    total = 0.0;
    for item in items {
        total = total + item.price * item.quantity;
    }
    tax = total * 0.08;
    return OrderSummary(
        order_id="ord-001",
        items=items,
        total=total,
        tax=tax
    );
}

def:pub update_item(order_id: str, item: CartItem) -> OrderSummary {
    return OrderSummary(
        order_id=order_id,
        items=[item],
        total=item.price * item.quantity,
        tax=0.0
    );
}

cl {
    sv import from .typed_bidirectional { place_order, update_item }

    def:pub app -> JsxElement {
        has cart: list = [],
            order: Any = None;

        async def checkout -> None {
            items = [
                CartItem(product_id="p1", name="Widget", quantity=2, price=9.99),
                CartItem(product_id="p2", name="Gadget", quantity=1, price=24.99)
            ];
            shipping = ShippingInfo(address="123 Main", city="Anytown");
            order = await place_order(items, shipping);
        }

        return <div>
            <h2>Order {order.order_id}</h2>
            <p>Total: {order.total} + Tax: {order.tax}</p>
            {[<span key={i.product_id}>{i.name} x{i.quantity}</span>
              for i in order.items]}
            <button onClick={checkout}>Checkout</button>
        </div>;
    }
}
