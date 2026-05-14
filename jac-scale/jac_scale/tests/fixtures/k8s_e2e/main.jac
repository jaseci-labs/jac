"""jac-shop - E-Commerce Microservice App.

Microservice architecture:
  - products_app.jac: catalog functions (list_products, get_product)
  - cart_app.jac: cart functions (view_cart, add_to_cart, clear_cart)
  - orders_app.jac: order functions; sv imports cart_app for inter-service calls
  - main.jac: this file - client UI + gateway entry point

Run: jac start main.jac
  Gateway on :8000
  Services auto-spawn on-demand via sv import (hash-based ports in 18xxx)
"""

# Client-side UI - served as static SPA by the gateway
to cl:

import from .frontend { app as ClientApp }

def:pub app -> any {
    return
        <ClientApp/>;
}
