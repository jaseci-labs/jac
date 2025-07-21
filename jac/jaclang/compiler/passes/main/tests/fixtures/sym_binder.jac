import M1;
# import M2 as m2alias;
# import M3, M4;
# import M5 as m5alias, M6 as m6alias;
# # import from M7 {M7S1}
# # import from M8 {M8S1 as m8s1alias, M8S2 as m8s2alias}
# # include M9;
# glob a = 5, k = 9;
# glob aa = 9;
# with entry{
#     Y: int;
#     Y = 0;
#     # b.Person.ss = 9;    
#     n = 0;
#     z = Y;
#     aa = 9;
# }
# with entry {
#     Y = 99;


# }
# import math,pandas,numpy as np, random as r;





import from math {cos}
import math;
import math;

def ccc() {
    # aa = 99; #Error:name 'aa' is assigned to before global declaration
    if (0) {
        global aa;
        global bb;
        aa = 88;
        bb = 0;
        p = 90;
        M1.k = 0;
    } 
    aa = 99;
    print(aa);
}
with entry {
    ccc();
    print(aa);
}


import random;



with entry{
    d = random.randint(1, 100);
    d = random.Random;
}

with entry{
    import sym_bin;
    sym_bin.foo();
}





     



     


obj A{
    has a: int;
}
with entry{
    A().a = 90;
    s = A();
    s.a= 9;
    print(A().a);
}

import sym_bin;
with entry{
    sym_bin.foo();
}


import random as r;
import from math {sqrt}

with entry{
    d = r.randint(1, 100);
    d = r.randint;
    a = {'a': 1, 'b': 2, 'c': 3};
}

import typing;

def foo(a:int, b: typing.Optional[int]) {
    ;
}