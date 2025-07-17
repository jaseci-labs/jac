walker Producer {
    can produce with `root entry;
}

node Product {
    has number: int;

    can make with Producer entry;
}

impl Producer.produce {
    end = here;
    for i=0; i<3; i+=1  {
        end ++> (end := Product(number=i + 1));
    }
    visit [-->];
}

impl Product.make {
    print(f"Hi, I am {self} returning a String");
    visit [-->];
}

with entry {
    root spawn Producer();
}
