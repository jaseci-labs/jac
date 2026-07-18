use jac_bridge::bridge;

#[bridge(module = "m")]
mod m {
    pub struct Foo(pub u8);

    impl Foo {
        // HashMap<String, V> marshals as dict[str, V], but only bool/int/uint/str
        // values are bridgeable — f64 has no value tag, so the macro rejects it.
        pub fn bad(&self) -> std::collections::HashMap<String, f64> {
            std::collections::HashMap::new()
        }
    }
}

fn main() {}
