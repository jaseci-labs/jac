use jac_bridge::bridge;

// `#[jac(shared)]` is retired (Phase 1.2.4): an unconditional retain-on-adopt
// leaks a fresh handle box. It must be a spanned compile error directing the
// author to a `&Self` return (the only alias the toolchain can prove), not a
// silently-accepted leak-by-construction annotation.
#[bridge(module = "m")]
mod m {
    pub struct Foo {
        v: bool,
    }

    impl Foo {
        pub fn new() -> Self {
            Foo { v: true }
        }

        #[jac(shared)]
        pub fn alias(&self) -> Foo {
            Foo { v: self.v }
        }
    }
}

fn main() {}
