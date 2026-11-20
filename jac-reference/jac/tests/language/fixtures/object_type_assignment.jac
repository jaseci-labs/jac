node A{}


with entry{
    hasattr(A,'9876');
    hasattr("jaclang.cli.impl.main",'9876');
    hasattr(A(),'9876');


    a:object = A();
    a:object = A;
}
