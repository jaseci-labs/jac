"""Shared node definitions for the jac-shop microservices.

All services share one anchor store (jac.toml's shelf_db_path), so every
service must be able to deserialize every node class that might appear
under root. Defining the classes here and importing from all three
services keeps the class registry consistent across the graph.

Owner notes (enforced by convention, not by code):
  - products_app writes Products + Product
  - cart_app writes Cart
  - orders_app writes Order
"""

node Products {}

node Product {
    has id: str,
        name: str,
        price: float,
        description: str = "",
        stock: int = 0;
}

node Cart {
    has items: list[dict] = [];
}

node Order {
    has id: str,
        items: list[dict] = [],
        total: float = 0.0,
        status: str = "pending",
        created_at: str = "";
}
