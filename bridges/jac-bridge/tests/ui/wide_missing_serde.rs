use jac_bridge::bridge;

#[bridge(module = "m")]
mod m {
    // The serde wide lane requires the payload type to implement
    // `Serialize`/`Deserialize`. `Plain` derives neither, so wrapping it in
    // `Wide<..>` must fail to compile with a trait-bound error naming the missing
    // impl — never a silently-wrong shim.
    pub struct Plain {
        pub x: i64,
    }

    pub struct Foo;

    impl Foo {
        pub fn new() -> Self {
            Foo
        }

        pub fn bad(&self) -> Wide<Plain> {
            Wide(Plain { x: 0 })
        }
    }
}

fn main() {}
