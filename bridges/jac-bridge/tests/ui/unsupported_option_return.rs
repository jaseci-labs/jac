use jac_bridge::bridge;

#[bridge(module = "m")]
mod m {
    pub struct Foo(pub u8);

    impl Foo {
        // Option<bool> has no in-band None channel (a null handle / null JacBuf
        // only exists for Option<Ref> and Option<String>), so the macro rejects
        // it rather than emit a shim that can't distinguish Some(false) from None.
        pub fn bad(&self) -> Option<bool> {
            None
        }
    }
}

fn main() {}
