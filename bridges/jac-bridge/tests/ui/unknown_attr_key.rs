use jac_bridge::bridge;

// An unknown key in the bridge attribute must be a spanned compile error, not a
// silent fallback to the default module name.
#[bridge(modle = "x")]
mod m {
    pub struct Foo(pub u8);

    impl Foo {
        pub fn x(&self) -> bool {
            true
        }
    }
}

fn main() {}
