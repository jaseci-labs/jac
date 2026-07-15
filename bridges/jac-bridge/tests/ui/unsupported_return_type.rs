use jac_bridge::bridge;

#[bridge(module = "m")]
mod m {
    pub struct Foo(pub u8);

    impl Foo {
        // char is not a bridgeable return type (no scalar tag in the v1 ABI).
        pub fn bad(&self) -> char {
            'x'
        }
    }
}

fn main() {}
