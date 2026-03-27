"""Client module for typed_bidirectional - separate file pattern.

Tests full round-trip typed object passing from a separate .cl.jac file.
"""

sv import from .typed_bidirectional { place_order, update_item }

def:pub app -> JsxElement {
    has order: Any = None;

    async def checkout -> None {
        items = [
            CartItem(product_id="p1", name="Widget", quantity=2, price=9.99)
        ];
        shipping = ShippingInfo(address="456 Oak Ave", city="Townsville");
        order = await place_order(items, shipping);
    }

    async def updateQuantity(itemId: str, qty: int) -> None {
        updated = CartItem(product_id=itemId, name="Widget", quantity=qty, price=9.99);
        order = await update_item(order.order_id, updated);
    }

    return <div>
        <h2>Order {order.order_id}</h2>
        <p>Status: {order.status}</p>
        <p>Total: ${order.total} (tax: ${order.tax})</p>
        <button onClick={checkout}>Place Order</button>
    </div>;
}
