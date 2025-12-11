obj mainObject;

impl mainObject{
    def greet;
    obj subObject;
}

def foo {
    obj ObjInsideFunction;
    return ObjInsideFunction();
}

impl foo.ObjInsideFunction{
    def bar {
        print("Hello,from bar in kk");
    }
}

with entry {
    foo().bar();
}

impl mainObject.greet{
    print("Greeting: Hello, World!");
}

impl mainObject.subObject{
    def displayMessage;
    def shortMessage {
        print("Hello, World!");
    }
    obj nestedObject;
}

impl mainObject.subObject.displayMessage{
    print("Repeated: Hello!");
}

impl mainObject.subObject.nestedObject{
    def lastMessage;
    def finalMessage {
        print("Final message:!");
    }
}

impl mainObject.subObject.nestedObject.lastMessage{
    print("Last message:!");
}

with entry {
    mainObject().greet();
    mainObject().subObject().displayMessage();
    mainObject().subObject().shortMessage();
    mainObject().subObject().nestedObject().lastMessage();
    mainObject().subObject().nestedObject().finalMessage();
}
