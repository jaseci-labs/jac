"""Implementations for the Jac Shop frontend.

In microservice mode, the client calls gateway function endpoints:
  /api/products/function/list_products
  /api/cart/function/add_to_cart
  /api/orders/function/create_order
"""

impl app.apiCall(service: str, endpoint: str, body: dict = {}) -> any {
    token = localStorage.getItem("jac_token");
    options: dict = {
        "method": "POST",
        "headers": {
            "Content-Type": "application/json",
            "Authorization": "Bearer " + (token or "")
        }
    };
    options["body"] = JSON.stringify(body or {});
    resp = await fetch(f"/api/{service}/function/{endpoint}", options);
    return await resp.json();
}

impl app.fetchProducts -> None {
    loading = True;
    data = await apiCall("products", "list_products", {});
    # Function response envelope: { ok, data: { result: [...] } }
    products = data.data.result if data.data and data.data.result else [];
    loading = False;
}

impl app.addToCart(productId: str, name: str, price: float) -> None {
    await apiCall(
        "cart",
        "add_to_cart",
        {"product_id": productId, "product_name": name, "price": price, "qty": 1}
    );
    fetchCart();
}

impl app.fetchCart -> None {
    data = await apiCall("cart", "view_cart", {});
    cart = data.data.result
        if data.data and data.data.result
        else {"items": [], "total": 0};
}

impl app.placeOrder -> None {
    # create_order handles everything server-side via sv import:
    # orders_app -> view_cart() on cart_app -> creates order -> clear_cart()
    result = await apiCall("orders", "create_order", {});
    order = result.data.result if result.data and result.data.result else {};

    if order.error {
        console.log("Order error:", order.error);
        return;
    }

    cart = {"items": [], "total": 0, "item_count": 0};
    currentView = "orders";
    fetchOrders();
}

impl app.fetchOrders -> None {
    data = await apiCall("orders", "list_orders", {});
    orders = data.data.result if data.data and data.data.result else [];
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
