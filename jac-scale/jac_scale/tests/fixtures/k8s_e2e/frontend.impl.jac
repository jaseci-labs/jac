"""Implementations for the Jac Shop frontend.

The cross-service functions are `sv import`ed directly (see frontend.cl.jac).
The compiler stamps each generated stub with its source-module provenance, so
the runtime routes each call to the owning service's gateway prefix:
  list_products -> /api/products/function/list_products
  add_to_cart   -> /api/cart/function/add_to_cart
  create_order  -> /api/orders/function/create_order
The stub already unwraps the function response envelope, returning the result
value directly.
"""

impl app.fetchProducts -> None {
    loading = True;
    products = await list_products() or [];
    loading = False;
}

impl app.addToCart(productId: str, name: str, price: float) -> None {
    await add_to_cart(productId, name, price, 1);
    fetchCart();
}

impl app.fetchCart -> None {
    cart = await view_cart() or {"items": [], "total": 0};
}

impl app.placeOrder -> None {
    # create_order handles everything server-side via sv import:
    # orders_app -> view_cart() on cart_app -> creates order -> clear_cart()
    order = await create_order() or {};

    if order.error {
        console.log("Order error:", order.error);
        return;
    }

    cart = {"items": [], "total": 0, "item_count": 0};
    currentView = "orders";
    fetchOrders();
}

impl app.fetchOrders -> None {
    orders = await list_orders() or [];
}

impl app.handleLogin -> None {
    error = "";
    if not username.trim() or not password {
        error = "Please fill in all fields";
        return;
    }
    loading = True;
    success = await jacLogin(username, password);
    loading = False;
    if success {
        isLoggedIn = True;
        username = "";
        password = "";
    } else {
        error = "Invalid username or password";
    }
}

impl app.handleSignup -> None {
    error = "";
    if not username.trim() or not password {
        error = "Please fill in all fields";
        return;
    }
    if password.length < 4 {
        error = "Password must be at least 4 characters";
        return;
    }
    loading = True;
    result = await jacSignup(username, password);
    loading = False;
    if result["success"] {
        isLoggedIn = True;
        username = "";
        password = "";
    } else {
        error = result["error"] if result["error"] else "Signup failed";
    }
}

impl app.handleLogout -> None {
    jacLogout();
    isLoggedIn = False;
    products = [];
    cart = {};
    orders = [];
    username = "";
    password = "";
    error = "";
    currentView = "products";
}

impl app.handleSubmit(e: any) -> None {
    e.preventDefault();
    if isSignup {
        await handleSignup();
    } else {
        await handleLogin();
    }
}
