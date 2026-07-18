use jac_bridge::bridge;

// `#[jac(assoc)]` marks a NO-receiver associated function as a static (FN_STATIC).
// Stamping it on a method that takes `self` is a contradiction — the macro rejects
// it with a spanned error rather than silently mislabelling a method as a static.
#[bridge(module = "m")]
mod m {
    pub struct Foo {
        v: bool,
    }

    impl Foo {
        pub fn new() -> Self {
            Foo { v: true }
        }

        #[jac(assoc)]
        pub fn other(&self) -> bool {
            self.v
        }
    }
}

fn main() {}
