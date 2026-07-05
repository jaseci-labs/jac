use jac_bridge::bridge;

#[bridge(module = "m")]
mod m {
    pub struct Foo(pub u8);

    impl Foo {
        // f64 is not a bridgeable boundary type (no float tag in the v1 ABI).
        pub fn bad(&self, x: f64) -> bool {
            let _ = x;
            true
        }
    }
}

fn main() {}
