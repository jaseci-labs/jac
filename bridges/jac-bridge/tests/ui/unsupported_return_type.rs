use jac_bridge::bridge;

#[bridge(module = "m")]
mod m {
    pub struct Foo(pub u8);

    impl Foo {
        // i32 is not a bridgeable return type.
        pub fn bad(&self) -> i32 {
            0
        }
    }
}

fn main() {}
