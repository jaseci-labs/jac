use jac_bridge::bridge;

// An impl block must target a type declared inside the same bridge module.
#[bridge(module = "m")]
mod m {
    pub struct Foo(pub u8);

    impl Bar {
        pub fn x(&self) -> bool {
            true
        }
    }
}

fn main() {}
