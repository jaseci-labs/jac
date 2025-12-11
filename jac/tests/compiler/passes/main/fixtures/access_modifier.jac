import access_checker;
import access_checker;

obj SomeObj {
    obj : pub InnerPublObj {}
    obj : priv InnerPrivObj {}
    obj : protect InnerProtObj {}

    enum : pub InnerPublEnum { FOO = "FOO" }
    enum : priv InnerPrivEnum { BAR = "BAR" }
    enum : protect InnerProtEnum { BAZ = "BAZ" }

    def : pub publ_ability()  -> None { }
    def : priv priv_ability()  -> None { }
    def : protect prot_ability()  -> None { }

    has : pub publ_attrib: int = 0;
    has : priv priv_attrib: int = 0;
    has : protect prot_attrib: int = 0;
}

obj BaseClass {
    has : pub publ_attrib: int = 0;
    has : priv priv_attrib: int = 0;
    has : protect prot_attrib: int = 0;

    def do_base()  -> None {
        self.publ_attrib;  # <-- okey.
        self.priv_attrib;  # <-- okey.
        self.prot_attrib;  # <-- okey.
    }
}

obj DrivedClass1(BaseClass) {
    def do_driv1()  -> None {
        self.publ_attrib;  # <-- okey.
        self.priv_attrib;  # <-- not okey.
        self.prot_attrib;  # <-- okey.
    }
}

# Check if the protect works from inherited chain.
obj DrivedClass2(BaseClass) {
    def do_driv2()  -> None {
        self.publ_attrib;  # <-- okey.
        self.priv_attrib;  # <-- not okey.
        self.prot_attrib;  # <-- okey.
    }
}

obj : pub Chain1 {
    has : priv priv_val: int = 0;  # <-- the private in the chain.
}

obj : pub Chain2 {
    has : pub chain1: Chain1 = Chain1();
}

obj : pub Chain3 {
    has : pub chain2: Chain2 = Chain2();
}

with entry {
    SomeObj.InnerPublObj;  # <-- okey.
    SomeObj.InnerPrivObj;  # <-- not okey.
    SomeObj.InnerProtObj;  # <-- not okey.

    SomeObj.InnerPublEnum;  # <-- okey.
    SomeObj.InnerPrivEnum;  # <-- not okey.
    SomeObj.InnerProtEnum;  # <-- not okey.

    some_obj = SomeObj();

    some_obj.InnerPublObj;  # <-- okey.
    some_obj.InnerPrivObj;  # <-- not okey.
    some_obj.InnerProtObj;  # <-- not okey.

    some_obj.InnerPublEnum;  # <-- okey.
    some_obj.InnerPrivEnum;  # <-- not okey.
    some_obj.InnerProtEnum;  # <-- not okey.

    some_obj.publ_attrib;  # <-- okey.
    some_obj.priv_attrib;  # <-- not okey.
    some_obj.prot_attrib;  # <-- not okey.

    some_obj.publ_ability();  # <-- okey.
    some_obj.priv_ability();  # <-- not okey.
    some_obj.prot_ability();  # <-- not okey.

    chain3: Chain3 = Chain3();
    chain3.chain2.chain1;  # <-- okey.
    chain3.chain2.chain1.priv_val;  # <-- not okey.

    access_checker.ModulePublObj();  # <-- okey.
    access_checker.ModulePrivObj();  # <-- not okey.

    access_checker.module_priv_glob;  # <-- okey.
    access_checker.module_priv_glob;  # <-- not okey.
}
