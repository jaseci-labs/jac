"""Jac Shop - Client-Side UI."""

import from "@jac/runtime" { jacSignup, jacLogin, jacLogout, jacIsLoggedIn }

import from .components.AuthForm { AuthForm }

# In microservice mode, walkers are called via gateway API
# /api/products/walker/ListProducts, /api/cart/walker/AddToCart, etc.
def:pub app -> any {
    has isLoggedIn: bool = False,
        checkingAuth: bool = True,
        isSignup: bool = False,
        username: str = "",
        password: str = "",
        error: str = "",
        loading: bool = False,
        products: list = [],
        cart: dict = {},
        orders: list = [],
        currentView: str = "products";

    can with entry {
        isLoggedIn = jacIsLoggedIn();
        console.log("Auth check complete, isLoggedIn =", isLoggedIn);
        if isLoggedIn {
            console.log("User is logged in, fetching products...");
            fetchProducts();
        }
        checkingAuth = False;
    }

    can with [isLoggedIn] entry {
        if isLoggedIn {
            fetchProducts();
        }
    }

    async def apiCall(service: str, endpoint: str, body: dict = {}) -> any;
    async def fetchProducts -> None;
    async def addToCart(productId: str, name: str, price: float) -> None;
    async def fetchCart -> None;
    async def placeOrder -> None;
    async def fetchOrders -> None;
    async def handleLogin -> None;
    async def handleSignup -> None;
    def handleLogout -> None;
    async def handleSubmit(e: any) -> None;

    # Loading screen
    if checkingAuth {
        return
            <div
                style={{
                    "display": "flex",
                    "justifyContent": "center",
                    "alignItems": "center",
                    "height": "100vh",
                    "fontFamily": "system-ui",
                    "color": "#666"
                }}
            >
                Loading...
            </div>;
    }

    # Logged in - Shop UI
    if isLoggedIn {
        return
            <div
                style={{
                    "maxWidth": "800px",
                    "margin": "2rem auto",
                    "padding": "2rem",
                    "fontFamily": "system-ui, -apple-system, sans-serif"
                }}
            >
                <div
                    style={{
                        "display": "flex",
                        "justifyContent": "space-between",
                        "alignItems": "center",
                        "marginBottom": "1.5rem"
                    }}
                >
                    <h1 style={{"margin": "0", "color": "#1a1a2e"}}>Jac Shop</h1>
                    <div style={{"display": "flex", "gap": "0.5rem"}}>
                        <button
                            onClick={lambda {
                                currentView = "products";
                                fetchProducts();
                            }}
                            style={{
                                "padding": "0.5rem 1rem",
                                "cursor": "pointer",
                                "backgroundColor": "transparent"
                                    if currentView != "products"
                                    else "#4CAF50",
                                "color": "#333"
                                    if currentView != "products"
                                    else "white",
                                "border": "1px solid #ddd",
                                "borderRadius": "6px"
                            }}
                        >
                            Products
                        </button>
                        <button
                            onClick={lambda {
                                currentView = "cart";
                                fetchCart();
                            }}
                            style={{
                                "padding": "0.5rem 1rem",
                                "cursor": "pointer",
                                "backgroundColor": "transparent"
                                    if currentView != "cart"
                                    else "#2196F3",
                                "color": "#333" if currentView != "cart" else "white",
                                "border": "1px solid #ddd",
                                "borderRadius": "6px"
                            }}
                        >
                            Cart
                        </button>
                        <button
                            onClick={lambda {
                                currentView = "orders";
                                fetchOrders();
                            }}
                            style={{
                                "padding": "0.5rem 1rem",
                                "cursor": "pointer",
                                "backgroundColor": "transparent"
                                    if currentView != "orders"
                                    else "#FF9800",
                                "color": "#333" if currentView != "orders" else "white",
                                "border": "1px solid #ddd",
                                "borderRadius": "6px"
                            }}
                        >
                            Orders
                        </button>
                        <button
                            onClick={handleLogout}
                            style={{
                                "padding": "0.5rem 1rem",
                                "cursor": "pointer",
                                "backgroundColor": "#f8f9fa",
                                "color": "#666",
                                "border": "1px solid #ddd",
                                "borderRadius": "6px"
                            }}
                        >
                            Log Out
                        </button>
                    </div>
                </div>
                {(
                    <div>
                        <h2>Products</h2>
                        {[
                            <div
                                key={p.id}
                                style={{
                                    "border": "1px solid #eee",
                                    "borderRadius": "8px",
                                    "padding": "1rem",
                                    "marginBottom": "0.75rem",
                                    "display": "flex",
                                    "justifyContent": "space-between",
                                    "alignItems": "center"
                                }}
                            >
                                <div>
                                    <strong>{p.name}</strong>
                                    <div
                                        style={{"color": "#666", "fontSize": "0.9rem"}}
                                    >
                                        {p.description}
                                    </div>
                                    <div
                                        style={{
                                            "color": "#4CAF50",
                                            "fontWeight": "bold"
                                        }}
                                    >
                                        ${p.price}
                                    </div>
                                </div>
                                <button
                                    onClick={lambda { addToCart(
                                        p.id, p.name, p.price
                                    );}}
                                    style={{
                                        "padding": "0.5rem 1rem",
                                        "backgroundColor": "#4CAF50",
                                        "color": "white",
                                        "border": "none",
                                        "borderRadius": "6px",
                                        "cursor": "pointer"
                                    }}
                                >
                                    Add to Cart
                                </button>
                            </div> for p in products
                        ]}
                    </div>
                )
                    if currentView == "products"
                    else None}
                {(
                    <div>
                        <h2>Shopping Cart</h2>
                        {(
                            <div>
                                {[
                                    <div
                                        key={item.product_id}
                                        style={{
                                            "border": "1px solid #eee",
                                            "borderRadius": "8px",
                                            "padding": "0.75rem",
                                            "marginBottom": "0.5rem",
                                            "display": "flex",
                                            "justifyContent": "space-between"
                                        }}
                                    >
                                        <span>{item.product_name} x{item.qty}</span>
                                        <span style={{"fontWeight": "bold"}}>
                                            ${item.line_total}
                                        </span>
                                    </div> for item in (cart.items or [])
                                ]}
                                <div
                                    style={{
                                        "textAlign": "right",
                                        "marginTop": "1rem",
                                        "fontSize": "1.2rem"
                                    }}
                                >
                                    <strong>Total: ${cart.total or 0}</strong>
                                </div>
                                <button
                                    onClick={lambda { placeOrder();}}
                                    style={{
                                        "marginTop": "1rem",
                                        "padding": "0.75rem 2rem",
                                        "backgroundColor": "#2196F3",
                                        "color": "white",
                                        "border": "none",
                                        "borderRadius": "8px",
                                        "cursor": "pointer",
                                        "width": "100%",
                                        "fontSize": "1rem"
                                    }}
                                >
                                    Place Order
                                </button>
                            </div>
                        )
                            if cart.items and cart.items.length > 0
                            else <p style={{"color": "#888", "textAlign": "center"}}>
                                Cart is empty
                            </p>}
                    </div>
                )
                    if currentView == "cart"
                    else None}
                {(
                    <div>
                        <h2>My Orders</h2>
                        {[
                            <div
                                key={o.id}
                                style={{
                                    "border": "1px solid #eee",
                                    "borderRadius": "8px",
                                    "padding": "0.75rem",
                                    "marginBottom": "0.5rem",
                                    "display": "flex",
                                    "justifyContent": "space-between"
                                }}
                            >
                                <span>{o.id}</span>
                                <span style={{"color": "#FF9800"}}>{o.status}</span>
                                <span style={{"fontWeight": "bold"}}>${o.total}</span>
                            </div> for o in orders
                        ]}
                        {(
                            <p style={{"color": "#888", "textAlign": "center"}}>
                                No orders yet
                            </p>
                        )
                            if orders.length == 0
                            else None}
                    </div>
                )
                    if currentView == "orders"
                    else None}
            </div>;
    }

    # Not logged in - Auth Form
    return
        <AuthForm
            isSignup={isSignup}
            username={username}
            password={password}
            error={error}
            loading={loading}
            onUsernameChange={lambda e: any { username = e.target.value;}}
            onPasswordChange={lambda e: any { password = e.target.value;}}
            onSubmit={handleSubmit}
            onToggleMode={lambda {
                isSignup = not isSignup;
                error = "";
            }}
        />;
}
