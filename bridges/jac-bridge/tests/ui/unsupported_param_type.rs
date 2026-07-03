use jac_bridge::bridge;

#[bridge(module = "m")]
mod m {
    pub struct Foo(pub u8);

    impl Foo {
        // i32 is not a bridgeable boundary type.
        pub fn bad(&self, x: i32) -> bool {
            let _ = x;
            true
        }
    }
}

fn main() {}
