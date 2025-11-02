node Bar {
  has baz: int;
}
node Foo {
  has bar: Bar;
}
with entry {
  bar_obj: Bar = Bar(23);
  f: Foo = Foo(bar=bar_obj);
  i: int = f.bar.baz; # <-- Ok
  s: str = f.bar.baz; # <-- Error
}
