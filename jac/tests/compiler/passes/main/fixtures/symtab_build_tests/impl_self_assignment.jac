obj SomeObj {
    has a: int = 5;

    def postinit;}

impl SomeObj.postinit {
    self.b = self.a * 3;
}

with entry {
    obj1 = SomeObj();
    print(obj1.a, obj1.b);

}