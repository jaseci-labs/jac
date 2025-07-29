enum personality{
    friendly= 1,
    curious= 2,
}


with entry{

    name = 'hello23232';
    l = f'hello {name}';

    e = f'''hello {name}  {f'world {name}'}''';
    print(l);
    print(e);

    e2 =  f''' first line
    second line
hello {name}
                       boom = {personality.friendly} hi {personality.friendly}''';
    print(e2);

}

with entry {
    name = 'Elon';

    ## Basic single and double quote f-strings
    l1 = f'Hello {name}!';
    l2 = f"Hi {name}, how are you?";

    ## Triple-quoted multiline f-strings
    l3 = f'''Line1
Line2
Hello {name}
Enum: {personality.friendly}
''';

    l4 = f"""Another example
This is {name}
Personality enum: {personality.curious}
""";

    ## Escaped quotes inside f-strings
    l5 = f'He said, "Hello {name}"';
    l6 = f"It\'s a good day for {name}";

    ## Nested f-strings (evaluate inner first and then outer)
    inner = f'inner {name}';
    l7 = f'Outer and {inner} end';

    ## Nested inline (not recommended but valid if formatted properly)
    l8 = f'Inline nested: {f"{name.upper()} rocks"}';

    ## Expressions in f-strings
    l9 = f'{name.upper()} is shouting!';
    l10 = f'{2 + 2} is four';
    l11 = f'{len(name)} letters in name';

    ## Enums inside f-strings
    l12 = f'Enum value: {personality.friendly}';

    ## Multiline with spacing and embedded expressions
    l13 = f'''First line
    {name} is on second line
    {personality.curious} is curious!
    ''';

    ## Invalid nesting (commented out to prevent errors)
    # bad = f'Invalid nesting {f"oops {name}"}'  # ❌ Not allowed in older versions of Python
    # l14 = f'''This is wrong: {personality.friendly f'{personality.friendly}'}'''  # ❌ SyntaxError

    ## Print all
    print(l1);
    print(l2);
    print(l3);
    print(l4);
    print(l5);
    print(l6);
    print(l7);
    print(l8);
    print(l9);
    print(l10);
    print(l11);
    print(l12);
    print(l13);


    txt = f"The price is 49 dollars";
    print(txt);

    price = 59;
    txt = f"The price is {price} dollars";
    print(txt);


    # # This needs to be supported
    # price = 59;
    # txt = f"The price is {price:.2f} dollars";
    # print(txt);



    # txt = f"The price is {95:.2f} dollars";
    # print(txt);


    txt = f"The price is {20 * 59} dollars";
    print(txt);


    price = 59;
    tax = 0.25;
    txt = f"The price is {price + (price * tax)} dollars";
    print(txt);


    price = 49;
    txt = f"It is very {'Expensive' if price>50 else 'Cheap'}";

    print(txt);


    fruit = "apples";
    txt = f"I love {fruit.upper()}";
    print(txt);


    def myconverter(x: float) -> float{
        return x * 0.3048;
    }

    txt = f"The plane is flying at a {myconverter(30000)} meter altitude";
    print(txt);

    # price = 59000;
    # txt = f"The price is {price:,} dollars";
    # print(txt);

    price = 49;
    txt = "The price is {} dollars";
    print(txt.format(price));

    txt = "The price is {:.2f} dollars";
    print(txt.format(price));


   quantity = 3;
    itemno = 567;
    price = 49;
    myorder = "I want {} pieces of item number {} for {:.2f} dollars.";
    print(myorder.format(quantity, itemno, price));



    quantity = 3;
    itemno = 567;
    price = 49;
    myorder = "I want {0} pieces of item number {1} for {2:.2f} dollars.";
    print(myorder.format(quantity, itemno, price));



    age = 36;
    name = "John";
    txt = "His name is {1}. {1} is {0} years old.";
    print(txt.format(age, name));


    myorder = "I have a {carname}, it is a {model}.";
    print(myorder.format(carname = "Ford", model = "Mustang"));




    name = "Jane";
    age = 25;
    f = "Hello, %(name)s! You're %(age)s years old." % {"name": "Jane", "age": 25};
    print(f);



    name = "Jane";
    age = 25;

    d ="Hello, {}! You're {} years old.".format(name, age);
    print(d);



    mm  = "Hello, {name}! You're {age} years old.".format(name="Jane", age=25);
    print(mm);

    person = {"name": "Jane", "age": 25};
    c = "Hello, {name}! You're {age} years old.".format(**person);
    print(c);


    h = f"{2 * 21}";
    print(h);
    y = f"{[2**n for n in range(3, 9)]}";
    print(y);


    class Person{

        def __init__(self:Person, name:str, age:int){
            self.name = name;
            self.age = age;
        }

        def __str__(self:Person){

            return f"I'm {self.name}, and I'm {self.age} years old.";
        }

        def __repr__(self:Person){
            return f"{type(self).__name__}(name='{self.name}', age={self.age})";
        }
    }


    jane = Person("Jane Doe", 25);
    print(f"{jane!s}");
    print(f"{jane!r}");
}

