"""Typed context blocks: Conditional code execution based on node/walker types."""

# Inheritance chain for products
node Product {
    has price: float;
}

node Media(Product) {
    has title: str;
}

node Book(Media) {
    has author: str;
}

node Magazine(Media) {
    has issue: int;
}

node Electronics(Product) {
    has name: str,
        warranty_years: int;
}

# Inheritance chain for customers
walker Customer {
    has name: str,
        total_spent: float = 0.0;
}

walker RegularCustomer(Customer) {
    has loyalty_points: int = 0;
}

walker VIPCustomer(Customer) {
    has vip_discount: float = 0.15;
}

# Walker that processes different item types
walker ShoppingCart {
    has items_count: int = 0,
        total: float = 0.0;

    can start with `root entry {
        # Create diverse inventory
        root ++> Book(title="Jac Programming", author="John Doe", price=29.99);
        root ++> Magazine(title="Tech Today", issue=42, price=5.99);
        root ++> Electronics(name="Laptop", price=999.99, warranty_years=2);

        visit [-->];
    }

    # Example 1: Base type in signature + typed context blocks for derived types
    # Ability accepts Product (base type), so ALL subtypes trigger this ability
    can process_item with Product entry {
        print(f"[Inheritance] Processing {type(here).__name__}...");

        # Typed context block for derived type Book
        ->Book{print(f"  -> Book block: '{here.title}' by {here.author}");}

        # Typed context block for derived type Magazine
        ->Magazine{print(f"  -> Magazine block: '{here.title}' Issue #{here.issue}");}

        # Typed context block for derived type Electronics
        ->Electronics{print(
            f"  -> Electronics block: {here.name}, {here.warranty_years}yr warranty"
        );}

        self.items_count += 1;
        self.total += here.price;
        visit [-->];
    }

    # Example 2: Multiple specific types in tuple (not using inheritance)
    # Ability ONLY triggers for the explicitly listed types
    can apply_discount with (Book, Magazine) entry {
        print(f"[Tuple] Applying media discount to {type(here).__name__}");

        # Typed context block differentiates between the tuple members
        ->Book{discount = here.price * 0.10;print(f"  -> Book: 10% off = ${discount}");}

        ->Magazine{discount = here.price * 0.20;print(
            f"  -> Magazine: 20% off = ${discount}"
        );}

        visit [-->];
    }
}

# Node that responds differently to different walker types
node Checkout {
    has transactions: int = 0;

    # Ability accepts base type Customer (all subtypes trigger this)
    # Typed context blocks select specific types in the inheritance chain
    can process_payment with Customer entry {
        self.transactions += 1;

        # Specific type: RegularCustomer (subtype of Customer)
        ->RegularCustomer{print(f"\nRegular customer: {visitor.name}");print(
            f"Total: ${visitor.total_spent}, Points: {visitor.loyalty_points}"
        );}

        # Specific type: VIPCustomer (subtype of Customer)
        ->VIPCustomer{discount = visitor.total_spent * visitor.vip_discount;final_total = visitor.total_spent - discount;print(
            f"\nVIP customer: {visitor.name}"
        );print(
            f"Subtotal: ${visitor.total_spent}, Discount: -${discount}, Final: ${final_total}"
        );}

        # Base type: Customer (matches all Customers including subtypes)
        ->Customer{print(f"Processing payment for {visitor.name}");}
    }
}

# Demo 1: ShoppingCart walker uses typed context blocks with inheritance
with entry {
    print("=== Demo 1: Product Inheritance Chain ===");
    print("Hierarchy: Product -> Media -> Book/Magazine");
    print("            Product -> Electronics\n");
}

glob cart = ShoppingCart();

with entry {
    root spawn cart;
    print(f"\nCart: {cart.items_count} items, Total: ${cart.total}\n");

    # Demo 2: Checkout node uses typed context blocks with customer inheritance
    print("=== Demo 2: Customer Inheritance Chain ===");
    print("Hierarchy: Customer -> RegularCustomer/VIPCustomer\n");
}

glob checkout = root ++> Checkout(),
     base_customer = Customer(name="Charlie", total_spent=50.00);

with entry {
    checkout spawn base_customer;
}

# Subtype RegularCustomer
glob regular = RegularCustomer(
         name="Alice", total_spent=89.97, loyalty_points=150
     );

with entry {
    checkout spawn regular;
}

# Subtype VIPCustomer
glob vip = VIPCustomer(
         name="Bob", total_spent=89.97, vip_discount=0.15
     );

with entry {
    checkout spawn vip;
}
# Base type Customer
