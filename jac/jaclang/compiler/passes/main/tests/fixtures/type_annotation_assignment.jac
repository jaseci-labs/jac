glob should_pass1: int = 42;
glob should_fail1: int = "foo";
glob should_pass2: str = "bar";
glob should_fail2: str = 42;

# This is without any explicit type annotation.
# was failing after the first PR.
glob should_be_fine = "baz";
