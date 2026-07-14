use jac_bridge::bridge;

// The ownership contract governs opaque-handle returns only. A #[jac(shared)] /
// #[jac(borrowed)] on a scalar return (here `bool`) must be a spanned compile
// error, not a silently-ignored annotation that emits a plain owned value.
#[bridge(module = "m")]
mod m {
    pub struct Foo {
        v: bool,
    }

    impl Foo {
        pub fn new() -> Self {
            Foo { v: true }
        }

        #[jac(borrowed)]
        pub fn peek(&self) -> bool {
            self.v
        }
    }
}

fn main() {}
