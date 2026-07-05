use jac_bridge::bridge;

#[bridge(module = "m")]
mod m {
    pub struct Foo(pub u8);

    impl Foo {
        // f64 is not a bridgeable return type (no float tag in the v1 ABI).
        pub fn bad(&self) -> f64 {
            0.0
        }
    }
}

fn main() {}
