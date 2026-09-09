"""Shared node definitions for the jac-shop service apps.

All services share one anchor store (jac.toml's shelf_db_path), so every
service must be able to deserialize every node class that might appear
under root. Defining the classes here and importing from all three
services keeps the class registry consistent across the graph.

Owner notes (enforced by convention, not by code):
  - products_app writes Products + Product
  - cart_app writes Cart
  - orders_app writes Order
"""

# A declared pip dep imported by a module the client entry reaches. The host
# builds the client bundle by importing the app's whole module graph, so this
# pins that the deploy gives the build host the app's [dependencies] too.
import humanize;


def qty_label(qty: int) -> str {
    return humanize.apnumber(qty);
}


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
