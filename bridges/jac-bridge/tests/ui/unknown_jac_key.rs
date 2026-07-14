use jac_bridge::bridge;

// An unknown key in the per-method #[jac(...)] ownership annotation must be a
// spanned compile error, not a silent default to owned.
#[bridge(module = "m")]
mod m {
    pub struct Foo {
        v: bool,
    }

    impl Foo {
        pub fn new() -> Self {
            Foo { v: true }
        }

        #[jac(bogus)]
        pub fn other(&self) -> Self {
            Foo { v: self.v }
        }
    }
}

fn main() {}
