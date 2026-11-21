"""jac-shop - an e-commerce workspace of service apps.

Apps (see jac.toml [apps]):
  - products_app: catalog functions (list_products, get_product)
  - cart_app: cart functions (view_cart, add_to_cart, clear_cart)
  - orders_app: order functions; bridges to cart_app across the app boundary
  - web (this file): client UI, hosts the gateway

Run: jac run web            (service apps colocated in-process)
     jac run web --fleet    (service apps as local processes behind :8000)
"""

# Client-side UI - served as static SPA by the gateway

import from .frontend { app as ClientApp }
import from shared.models { qty_label }

def:pub app -> any {
    <ClientApp/>
}


def:pub cart_label(qty: int) -> str {
    return qty_label(qty);
}
