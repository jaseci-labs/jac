node N {}

glob my_node: N = N();

walker GoodWalker {
    can visit with Root entry {
        ;
    }  # valid - Root is the class


    can visit2 with Root | N entry {
        ;
    }  # valid - union of classes

}

walker BadWalker {
    can visit with root entry {
        ;
    }  # E1116 - root keyword is a runtime instance

}

walker BadBacktickRoot {
    can visit with `root entry {
        ;
    }  # E1116 - `root (escaped keyword) is the root value, not the Root class

}

walker BadUnion {
    can visit with Root | root entry {
        ;
    }  # E1116 - root inside | union

}

walker BadTuple {
    can visit with (Root, root) entry {
        ;
    }  # E1116 - root inside tuple form

}

walker BadVarInstance {
    can visit with my_node entry {
        ;
    }  # E1116 - my_node is a variable holding an instance, not a class

}

walker BadVarUnion {
    can visit with Root | my_node entry {
        ;
    }  # E1116 - my_node inside | union

}

walker BadVarTuple {
    can visit with (Root, my_node) entry {
        ;
    }  # E1116 - my_node inside tuple form

}

walker BadCallInstance {
    can visit with N() entry {
        ;
    }  # E1116 - N() is a call expr yielding an instance, not a class

}
