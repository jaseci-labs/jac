import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o", config={"verbose": False}),
     omg: str = "Hello, JacLang with ByLLM!";

obj blob1 {
    has name: str;
}

obj blob2 {
    has id: int,
        blob: blob1;
}

obj blob3 {
    has items: list[blob2];

    def foo(para1: str, blob: blob2) -> blob3 by llm();
}

# def foo(para1: str, blob: blob2) -> blob3 by llm();
glob b1 = blob1(name="para1"),
     b2 = blob2(id=56, blob=b1),
     b3 = blob3(items=[b2]),
     n4 = b3.foo("para1", b2);

with entry {
    print(n4);
}

sem blob2 = "Semstring 1";
sem blob2.id = "Semstring 2";
sem blob2.blob = "Semstring 3";
sem blob3.items = "Semstring 4";
sem blob3.foo.para1 = "Semstring 6";
sem omg = "Semstring 5";
