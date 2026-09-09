"""Shared helpers for the jac-shop apps.

Node classes are NOT here. Each service app declares the nodes it writes,
inside its own app root, because a node or edge never crosses an app
boundary (E5108). What is left is a pure helper the web app reaches.

  - products_app declares and writes Products + Product
  - cart_app declares and writes Cart
  - orders_app declares and writes Order
"""

# A declared pip dep imported by a module the client entry reaches. The host
# builds the client bundle by importing the app's whole module graph, so this
# pins that the deploy gives the build host the app's [dependencies] too.
import humanize;


def qty_label(qty: int) -> str {
    return humanize.apnumber(qty);
}
