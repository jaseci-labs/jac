node Foo {
  # We can infer the type of `bar` but the jac
  # syntax makes the type annotation a must here.
  has bar: int = 42;
}
with entry {
  f: Foo = Foo();

  i = 42; s = "foo";

  i = f.bar; # <-- Ok
  s = f.bar; # <-- Error
}
