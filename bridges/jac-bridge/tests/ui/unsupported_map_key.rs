use jac_bridge::bridge;

#[bridge(module = "m")]
mod m {
    pub struct Foo(pub u8);

    impl Foo {
        // Only HashMap<String, V> is bridgeable — keys marshal as Jac str, so a
        // non-String key type (here u32) is rejected rather than silently dropped.
        pub fn bad(&self) -> std::collections::HashMap<u32, i64> {
            std::collections::HashMap::new()
        }
    }
}

fn main() {}
