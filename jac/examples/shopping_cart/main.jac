import datetime;

obj Metadata {
    has brand: str,
        model_number: str,
        release_date: str,
        echo_friendly: bool,
        digital_download: bool;
}

obj Gift {
    has is_gift_eligible: bool,
        gift_wrap_price: float,
        gift_message_allowed: bool;
}

obj Inventory {
    has stock_level: int,
        backorder_allowed: bool,
        estimated_restock_date: str;
}

obj Discounts {
    has discount_rate: float,
        eligible_coupons: list[str],
        bulk_discount_threshold: int,
        bulk_discount_amount: float;
}

obj Shipping {
    has weight: float,
        dimensions: tuple,
        is_fragile: bool,
        shipping_class: str,
        origin_location: str;
}

obj CoreInfo {
    has id: str,
        name: str,
        category: str,
        price: float,
        quantity: int,
        tags: list[str] = [];
}

obj Pricing {
    has tax_rate: float = 0,
        price: float = 0,
        discount_rate: float = 0,
        final_price: float = 0;
}

node Item {
    has core_info: CoreInfo,
        shipping: Shipping,
        discount: Discounts,
        inventory: Inventory,
        gift_option: Gift,
        metadata: Metadata,
        pricing: Pricing;
}

walker create_item {
    has core_info: CoreInfo,
        shipping: Shipping,
        discount: Discounts,
        inventory: Inventory,
        gift_option: Gift,
        metadata: Metadata,
        tax_rate: float;

    can create with `root entry {
        final_price = self.core_info.price * (
            1 - self.discount.discount_rate + self.tax_rate
        );
        pricing = Pricing(
            self.tax_rate,
            self.core_info.price,
            self.discount.discount_rate,
            final_price
        );
        root ++> Item(
            self.core_info,
            self.shipping,
            self.discount,
            self.inventory,
            self.gift_option,
            self.metadata,
            pricing
        );
        print([root-->]);
        report [root-->];
    }
}

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

walker calculate_shipping_weight {
    can calculate with Item entry;
}

walker apply_coupon {
    has coupon_code: str = "";

    can apply with Item entry;
}

walker is_discount_applicable {
    can is_discount with Item entry;
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

walker get_category {
    can get with Item entry;
}

walker get_tags {
    can get with Item entry;
}

walker get_inventory_status {
    can get with Item entry;
}
