use jac_bridge::bridge;

// A fallible function needs a #[jac_error] type so callers can retrieve the
// error message. Returning Result without one must be rejected.
#[bridge(module = "m")]
mod m {
    pub struct Foo(pub u8);

    impl Foo {
        pub fn make() -> Result<Self, String> {
            Ok(Foo(0))
        }
    }
}

fn main() {}
