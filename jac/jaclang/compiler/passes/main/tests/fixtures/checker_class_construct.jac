glob RAD = 5.0;

obj Circle1{
    has radius:float ,age:int;
    def init(color:str){
        self.color = color;
    }
}
with entry {
    c1 = Circle1(RAD);
}
# ---------------------------------------------------------------
glob length = 5.0;

obj Square{
    has side_length:float ,age:int;
}

with entry {
    c2 = Square(length);
}
# ---------------------------------------------------------------

glob name = "John";

obj Person{
    has name:str ,age:int=90;
}

with entry {
    c = Person(name=name, age=25);
    c = Person();
}