use jac_bridge::bridge;

// The D2 metadata reserves exactly one error type per module.
#[bridge(module = "m")]
mod m {
    #[jac_error]
    pub struct FirstError;

    #[jac_error]
    pub struct SecondError;
}

fn main() {}
