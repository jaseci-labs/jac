# Shopping Cart: Object Spatial Programming Example

This example demonstrates how Jac's Object Spatial Programming (OSP) paradigm elegantly solves the classic "Shopping Cart Problem" and the broader Expression Problem through spatial separation of data and behavior.

## The Expression Problem

The Expression Problem is a fundamental challenge in programming language design:

> *How can we add both new types and new operations to a program without modifying existing code, while maintaining type safety and modularity?*

Traditional approaches have inherent limitations:
- **Object-Oriented Programming**: Easy to add new types, difficult to add new operations
- **Functional Programming**: Easy to add new operations, difficult to add new types

## Traditional OOP Challenges

Consider a typical shopping cart implementation with multiple item types requiring various operations:

```python
# Traditional Python approach
class Item:
    def calculate_shipping(self):
        raise NotImplementedError
    
    def calculate_tax(self):
        raise NotImplementedError
    
    def calculate_final_price(self):
        raise NotImplementedError
    
    def apply_discount(self):
        raise NotImplementedError

class Book(Item):
    def calculate_shipping(self):
        return 5.0
    
    def calculate_tax(self):
        return self.price * 0.08
    
    # ... more methods for each operation

# Adding a new operation requires modifying ALL classes
# Adding a new type requires implementing ALL operations
```

### Problems with Traditional Approach

1. **Violation of Open/Closed Principle**: Adding operations requires modifying existing classes
2. **Scattered Logic**: Related operations are distributed across multiple classes
3. **Tight Coupling**: Data structure changes affect all operations
4. **Maintenance Burden**: Every new item type must implement every operation

## Jac's Spatial Solution

Jac solves these problems through Object Spatial Programming, which separates data structure from behavioral operations using spatial relationships.

### Core Architecture

The implementation uses a sophisticated modular design with separate objects for different concerns:

```jac
# Data structure definition (main.jac)
obj CoreInfo {
    has id: str;
    has name: str;
    has category: str;
    has price: float;
    has quantity: int;
    has tags: list[str] = [];
}

obj Shipping {
    has weight: float;
    has dimensions: tuple;
    has is_fragile: bool;
    has shipping_class: str;
    has origin_location: str;
}

obj Discounts {
    has discount_rate: float;
    has eligible_coupons: list[str];
    has bulk_discount_threshold: int;
    has bulk_discount_amount: float;
}

obj Inventory {
    has stock_level: int;
    has backorder_allowed: bool;
    has estimated_restock_date: str;
}

obj Gift {
    has is_gift_eligible: bool;
    has gift_wrap_price: float;
    has gift_message_allowed: bool;
}

obj Metadata {
    has brand: str;
    has model_number: str;
    has release_date: str;
    has echo_friendly: bool;
    has digital_download: bool;
}

obj Pricing {
    has tax_rate: float = 0;
    has price: float = 0;
    has discount_rate: float = 0;
    has final_price: float = 0;
}

node Item {
    has core_info: CoreInfo;
    has shipping: Shipping;
    has discount: Discounts;
    has inventory: Inventory;
    has gift_option: Gift;
    has metadata: Metadata;
    has pricing: Pricing;
}
```

### Walker Declarations

Operations are declared as walkers that can traverse and operate on the spatial structure:

```jac
walker get_base_price {
    can get with Item entry;
}

walker calculate_discount {
    can calculate with Item entry;
}

walker calculate_tax {
    can calculate with Item entry;
}

walker calculate_final_price {
    can calculate with Item entry;
}

walker calculate_shipping {
    can calculate with Item entry;
}

walker is_eligible_for_free_shipping {
    can is_eligible with Item entry;
}

walker apply_coupon {
    has coupon_code: str = "";
    can apply with Item entry;
}

walker apply_bulk_discount {
    has quantity: int;
    can apply with Item entry;
}

walker is_gift_eligible {
    can is_gift with Item entry;
}

walker calculate_gift_wrap_fee {
    can calculate with Item entry;
}

walker get_inventory_status {
    can get with Item entry;
}
```

### Behavioral Operations (main.impl.jac)

Operations are implemented separately using the `impl` pattern:

#### Price and Discount Operations

```jac
impl get_base_price.get {
    report here.core_info.price;
}

impl calculate_discount.calculate {
    discount_amount = here.core_info.price * here.discount.discount_rate;
    report discount_amount;
}

impl calculate_final_price.calculate {
    base_price = here.core_info.price;
    discount_amount = base_price * here.discount.discount_rate;
    tax_amount = (base_price - discount_amount) * 0.08;
    final_price = base_price - discount_amount + tax_amount;
    report final_price;
}

impl apply_coupon.apply {
    if self.coupon_code in here.discount.eligible_coupons {
        # Apply 15% additional discount for valid coupons
        coupon_discount = here.core_info.price * 0.15;
        report coupon_discount;
    } else {
        report 0.0;
    }
}

impl apply_bulk_discount.apply {
    if self.quantity >= here.discount.bulk_discount_threshold {
        bulk_discount = here.discount.bulk_discount_amount * self.quantity;
        report bulk_discount;
    } else {
        report 0.0;
    }
}
```

#### Shipping Operations

```jac
impl calculate_shipping.calculate {
    base_shipping = 5.0;  # Base shipping cost
    weight_cost = here.shipping.weight * 0.5;  # $0.5 per unit weight
    
    if here.shipping.shipping_class == "express" {
        shipping_cost = (base_shipping + weight_cost) * 2;
    } elif here.shipping.shipping_class == "overnight" {
        shipping_cost = (base_shipping + weight_cost) * 3;
    } else {
        shipping_cost = base_shipping + weight_cost;
    }
    
    if here.shipping.is_fragile {
        shipping_cost += 10.0;  # Fragile handling fee
    }
    
    report shipping_cost;
}

impl is_eligible_for_free_shipping.is_eligible {
    # Free shipping for orders over $50 or lightweight items
    is_eligible = here.core_info.price >= 50.0 or here.shipping.weight <= 1.0;
    report is_eligible;
}

impl calculate_shipping_weight.calculate {
    total_weight = here.shipping.weight * here.core_info.quantity;
    report total_weight;
}
```

#### Tax and Gift Operations

```jac
impl calculate_tax.calculate {
    tax_rate = 0.08;
    tax_amount = here.core_info.price * tax_rate;
    report tax_amount;
}

impl is_gift_eligible.is_gift {
    report here.gift_option.is_gift_eligible;
}

impl calculate_gift_wrap_fee.calculate {
    if here.gift_option.is_gift_eligible {
        report here.gift_option.gift_wrap_price;
    } else {
        report 0.0;
    }
}

impl get_inventory_status.get {
    if here.inventory.stock_level > 0 {
        report "In Stock";
    } elif here.inventory.backorder_allowed {
        report "Available for Backorder";
    } else {
        report "Out of Stock";
    }
}
```

### Item Creation and Usage

```jac
walker create_item {
    has core_info: CoreInfo;
    has shipping: Shipping;
    has discount: Discounts;
    has inventory: Inventory;
    has gift_option: Gift;
    has metadata: Metadata;
    has tax_rate: float;

    can create with `root entry {
        final_price = self.core_info.price * (1 - self.discount.discount_rate + self.tax_rate);
        pricing = Pricing(self.tax_rate, self.core_info.price, self.discount.discount_rate, final_price);
        root ++> Item(self.core_info, self.shipping, self.discount, self.inventory, self.gift_option, self.metadata, pricing);
        print([root -->]);
        report [root -->];
    }
}

with entry {
    # Create item components
    core_info = CoreInfo(
        id="ITEM001",
        name="Wireless Headphones",
        category="Electronics",
        price=199.99,
        quantity=2,
        tags=["wireless", "bluetooth", "audio"]
    );
    
    shipping_info = Shipping(
        weight=0.8,
        dimensions=(8, 6, 3),
        is_fragile=True,
        shipping_class="standard",
        origin_location="warehouse_a"
    );
    
    discount_info = Discounts(
        discount_rate=0.10,
        eligible_coupons=["SAVE15", "WELCOME"],
        bulk_discount_threshold=5,
        bulk_discount_amount=25.0
    );
    
    inventory_info = Inventory(
        stock_level=15,
        backorder_allowed=True,
        estimated_restock_date="2024-02-15"
    );
    
    gift_info = Gift(
        is_gift_eligible=True,
        gift_wrap_price=5.99,
        gift_message_allowed=True
    );
    
    metadata_info = Metadata(
        brand="AudioTech",
        model_number="AT-WH100",
        release_date="2023-11-01",
        echo_friendly=True,
        digital_download=False
    );
    
    # Create item
    item_creator = create_item(
        core_info, shipping_info, discount_info, 
        inventory_info, gift_info, metadata_info, 0.08
    );
    item_creator.visit(root);
    
    # Get the created item
    item = [root -->][0];
    
    # Use various operations
    price_walker = get_base_price();
    base_price = price_walker.visit(item);
    
    shipping_walker = calculate_shipping();
    shipping_cost = shipping_walker.visit(item);
    
    tax_walker = calculate_tax();
    tax_amount = tax_walker.visit(item);
    
    final_price_walker = calculate_final_price();
    final_price = final_price_walker.visit(item);
    
    # Check gift eligibility
    gift_walker = is_gift_eligible();
    is_gift = gift_walker.visit(item);
    
    # Apply coupon
    coupon_walker = apply_coupon(coupon_code="SAVE15");
    coupon_discount = coupon_walker.visit(item);
    
    # Display results
    print(f"Base Price: ${base_price:.2f}");
    print(f"Shipping Cost: ${shipping_cost:.2f}");
    print(f"Tax Amount: ${tax_amount:.2f}");
    print(f"Final Price: ${final_price:.2f}");
    print(f"Gift Eligible: {is_gift}");
    print(f"Coupon Discount: ${coupon_discount:.2f}");
}
```

## Adding New Operations

Adding a return policy calculator requires no changes to existing code:

```jac
walker calculate_return_fee {
    can calculate with Item entry;
}

walker is_returnable {
    can check with Item entry;
}

# Implementation
impl calculate_return_fee.calculate {
    # Different return fees based on category
    if here.core_info.category == "Electronics" {
        return_fee = here.core_info.price * 0.05;  # 5% restocking fee
    } elif here.metadata.digital_download {
        return_fee = 0.0;  # No returns for digital items
    } else {
        return_fee = 10.0;  # Flat fee for other items
    }
    report return_fee;
}

impl is_returnable.check {
    # Digital downloads are not returnable
    if here.metadata.digital_download {
        report False;
    }
    # Items over 30 days old may not be returnable
    # (simplified logic for demonstration)
    report True;
}
```

## Adding New Item Properties

Adding warranty information requires only extending the data structure:

```jac
obj Warranty {
    has duration_months: int;
    has coverage_type: str;
    has warranty_provider: str;
    has extended_warranty_available: bool;
}

# Update Item node
node Item {
    # ...existing code...
    has warranty: Warranty;
}

# Add warranty-related operations
walker calculate_warranty_cost {
    can calculate with Item entry;
}

impl calculate_warranty_cost.calculate {
    if here.warranty.extended_warranty_available {
        base_cost = here.core_info.price * 0.08;  # 8% of item price
        duration_factor = here.warranty.duration_months / 12.0;
        warranty_cost = base_cost * duration_factor;
        report warranty_cost;
    } else {
        report 0.0;
    }
}
```

## Benefits of the Spatial Approach

### Modularity and Separation of Concerns

1. **Component-Based Design**: Each object handles a specific aspect (shipping, pricing, inventory)
2. **Operation Encapsulation**: Each walker encapsulates a single business operation
3. **Loose Coupling**: Operations don't depend on internal item implementations

### Extensibility

1. **Easy Operation Addition**: New walkers integrate seamlessly
2. **Flexible Data Extension**: Add new object components without breaking existing code
3. **Scalable Architecture**: System grows naturally with business requirements

### Maintainability

1. **Centralized Logic**: Related operations are grouped by walker type
2. **Clear Responsibilities**: Each component has a well-defined purpose
3. **Implementation Separation**: Logic is separated from declarations using `impl`

## Comparison with Traditional Approaches

| Aspect | Traditional OOP | Jac OSP |
|--------|----------------|---------|
| Adding Operations | Modify all classes | Add new walker + impl |
| Adding Properties | Modify class structure | Add new objects |
| Logic Location | Mixed in classes | Centralized in walkers |
| Business Rules | Scattered | Grouped by operation |
| Testing | Complex mocking | Simple walker testing |
| Code Reuse | Limited inheritance | Flexible walker composition |

## Best Practices

1. **Single Responsibility**: Each object and walker handles one concern
2. **Clear Naming**: Use descriptive names that reflect business operations
3. **Modular Design**: Break complex data into focused objects
4. **Implementation Separation**: Use `impl` pattern for clean organization
5. **Error Handling**: Include validation in walker implementations
6. **Documentation**: Document business rules within walkers

## Conclusion

Jac's Object Spatial Programming paradigm provides an elegant solution to the Expression Problem by:

- **Separating Structure from Behavior**: Nodes hold structured data, walkers provide operations
- **Enabling Modular Design**: Component-based architecture with focused responsibilities
- **Supporting True Extensibility**: Add operations and data without modifying existing code
- **Improving Business Logic Organization**: Group related operations in walkers
- **Facilitating Testing**: Walker-based operations are easily testable in isolation

This spatial approach transforms complex business domains into clean, modular, and extensible systems that adapt gracefully to changing requirements while maintaining clear architectural boundaries.