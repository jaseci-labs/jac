"""Products Service - catalog management.

Exposes public functions for browsing products. Callable via:
  - HTTP: POST /api/products/function/{name}
  - sv import: `sv import from products_app { list_products, get_product }`
"""

import from shared.models { Products, Product, Cart, Order }

glob CATALOG: list[dict] = [
         {
             "id": "prod_1",
             "name": "Wireless Headphones",
             "price": 49.99,
             "stock": 25,
             "description": "Bluetooth over-ear headphones"
         },
         {
             "id": "prod_2",
             "name": "USB-C Hub",
             "price": 34.99,
             "stock": 50,
             "description": "7-in-1 USB-C hub with HDMI"
         },
         {
             "id": "prod_3",
             "name": "Mechanical Keyboard",
             "price": 89.99,
             "stock": 15,
             "description": "RGB mechanical keyboard"
         },
         {
             "id": "prod_4",
             "name": "Laptop Stand",
             "price": 29.99,
             "stock": 40,
             "description": "Adjustable aluminum laptop stand"
         },
         {
             "id": "prod_5",
             "name": "Webcam HD",
             "price": 59.99,
             "stock": 30,
             "description": "1080p webcam with microphone"
         }
     ];

def _get_or_seed_anchor -> Products {
    existing = [root()-->][?:Products];
    if existing {
        return existing[0];
    }
    anchor = (root() ++> Products())[0];
    for p in CATALOG {
        anchor ++> Product(
            id=p["id"],
            name=p["name"],
            price=p["price"],
            stock=p["stock"],
            description=p["description"]
        );
    }
    return anchor;
}

to sv:

def:pub list_products -> list[dict] {
    anchor = _get_or_seed_anchor();
    items: list = [];
    for p in [anchor-->][?:Product] {
        items.append(
            {
                "id": p.id,
                "name": p.name,
                "price": p.price,
                "description": p.description,
                "stock": p.stock
            }
        );
    }
    return items;
}

def:pub get_product(product_id: str) -> dict {
    anchor = _get_or_seed_anchor();
    for p in [anchor-->][?:Product] {
        if p.id == product_id {
            return {
                "id": p.id,
                "name": p.name,
                "price": p.price,
                "description": p.description,
                "stock": p.stock
            };
        }
    }
    return {"error": "Product not found"};
}

@restspec(protocol=APIProtocol.WEBSOCKET)
async walker : pub EchoMessage {
    has message: str;

    async can echo with Root entry {
        report {"echo": self.message, "from": "products_app"};
    }
}
