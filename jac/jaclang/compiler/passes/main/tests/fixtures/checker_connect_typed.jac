edge MyEdge {
  has id: int;
}

node A {
  has val: int;
}

node B {
  has name: str;
}

with entry {
  a: A = A(0);
  b: B = B("bob");
  a +>:MyEdge:+> b;
  edge_inst: MyEdge = MyEdge(1);
  a +>:edge_inst:+> b;
  a +>:A:+> b;          # ERROR
  A +>:MyEdge:+> b;     # ERROR
  a +>:MyEdge:+> B;     # ERROR
}
