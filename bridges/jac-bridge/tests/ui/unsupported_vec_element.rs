use jac_bridge::bridge;

#[bridge(module = "m")]
mod m {
    pub struct Foo(pub u8);

    impl Foo {
        // Vec<V> marshals as list[V], but only bool/int/uint/str elements are
        // bridgeable — f64 has no element tag, so the macro rejects it.
        pub fn bad(&self) -> Vec<f64> {
            Vec::new()
        }
    }
}

fn main() {}
