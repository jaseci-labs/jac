# na cliff: Python EXCEPTION MATCHING modeled as data. jac-py core site is
# pyc_first.jac's CHECK_EXC_MATCH / exception_matches (~3772) + class_mro (~3915):
# a raised user-exception instance carries its class; each `except` arm's class is
# matched by walking the raised instance's MRO --
#     for klass in class_mro((raw as PyUserObj).cls) {
#         if klass is (target as PyClass) { return True; }   # isinstance semantics
#     }
# -- and the bytecode checks arms in LEXICAL order, so the FIRST arm whose class is
# the raised class OR a base of it wins (CPython first-match, NOT best/most-derived).
#
# na exceptions are LEXICALLY structured -- you cannot jump into the middle of a
# try to reach a handler (see sibling cliff_gen_frame). So handler SELECTION is
# lifted to DATA: an "except table" of (exc_class, handler_id) arms is walked in
# order, each arm tested by MRO membership, and the winning handler_id is RETURNED
# as an integer -- mirroring how cliff_gen_frame lifted control flow to integer
# state instead of jumping into a lexical block.
#
# Uncheatable properties (an easy compile proves nothing):
#  * the raised class is RUNTIME-computed (indexed out of a data list, never a
#    literal at the match site), and matching runs in a loop over scenarios;
#  * BASE match, not just exact: a Leaf instance is caught by a `Mid` arm two
#    levels up the MRO -- so the walk genuinely traverses the hierarchy;
#  * ARM-ORDER precedence: with a broad `Base` arm BEFORE a specific `Mid` arm and
#    a Leaf raised, BOTH match by MRO, but the earlier broad arm must win -- proving
#    first-match, not best/most-derived match (best-match would pick Mid);
#  * NO-MATCH must propagate: a sibling instance against a `Mid`-only table matches
#    no arm and returns the propagate sentinel (defeats a "return first arm" cheat);
#  * every winning handler_id flows into an accumulator the final assert reads.
# Class identity is carried as a unique int `cid` (a DATA stand-in for the `is`
# identity the bytecode path uses), so the MRO membership test is real identity,
# not name-equality. Memory: na-method-call-on-union-receiver, na-lexical-exceptions.

# ---- minimal PyObj core (self-contained; no `import from`) ----
obj PyObj {
    has t: str;
}

# A user class: a unique identity `cid` + its direct bases. Single-inheritance
# chains here, but bases is a list so the MRO walk is a genuine recursion.
obj PyClass(PyObj) {
    has name: str,
        cid: int,
        bases: list[PyObj] = [];
}

# A raised exception instance carries only its class -- matching is entirely a
# function of the class MRO, exactly as the raw PyUserObj feeds class_mro.
obj PyInstance(PyObj) {
    has cls: PyClass;
}

# One `except <Class>:` arm, as DATA: the class to match and the integer id of the
# handler that runs if it matches. The na-clean stand-in for a lexical handler.
obj PyExcArm(PyObj) {
    has cls: PyClass,
        handler_id: int;
}

# ---- MRO walk (recursive linearization), mirroring pyc_first class_mro ----
def class_mro(cls: PyClass) -> list[PyClass] {
    result: list[PyClass] = [cls];
    for base in cls.bases {
        if isinstance(base, PyClass) {
            for klass in class_mro(base as PyClass) {
                result.append(klass);
            }
        }
    }
    return result;
}

# isinstance semantics: is `target` the raised instance's class OR a base of it?
# Walk the MRO and compare identity (unique cid). This is the `klass is target`
# test from exception_matches, lifted to a data-driven membership walk.
def instance_of(inst: PyInstance, target: PyClass) -> bool {
    for klass in class_mro(inst.cls) {
        if klass.cid == target.cid {
            return True;
        }
    }
    return False;
}

# ---- THE MATCHER: handler selection as data ----
# Walk the except table in ARM ORDER; the FIRST arm whose class matches the raised
# instance by MRO wins and its handler_id is returned. No match -> propagate
# sentinel (-1). This is CPython's first-match-wins over the lexical arm order,
# with the handler chosen as DATA rather than by jumping into a lexical block.
def dispatch_raise(raised: PyInstance, table: list[PyExcArm]) -> int {
    for arm in table {
        if instance_of(raised, arm.cls) {
            return arm.handler_id;
        }
    }
    return -1;
}

# ---- builders (avoid dict/subclass-value literals; build + append) ----
def make_class(nm: str, id: int, bases: list[PyObj]) -> PyClass {
    return PyClass(t="type", name=nm, cid=id, bases=bases);
}

def make_inst(c: PyClass) -> PyInstance {
    return PyInstance(t="obj", cls=c);
}

def make_arm(c: PyClass, hid: int) -> PyExcArm {
    return PyExcArm(t="arm", cls=c, handler_id=hid);
}

# The scenarios return a single encoded int the ref pins. Hierarchy:
#   Base(1) <- Mid(2) <- Leaf(3) ; Sib(4) <- Base  (sibling of Mid under Base)
# MRO(Leaf)=[Leaf,Mid,Base]  MRO(Sib)=[Sib,Base]
def run -> int {
    no_bases: list[PyObj] = [];
    base_cls = make_class("Base", 1, no_bases);

    mid_bases: list[PyObj] = [base_cls];
    mid_cls = make_class("Mid", 2, mid_bases);

    leaf_bases: list[PyObj] = [mid_cls];
    leaf_cls = make_class("Leaf", 3, leaf_bases);

    sib_bases: list[PyObj] = [base_cls];
    sib_cls = make_class("Sib", 4, sib_bases);

    # Classes live in a DATA list; the raised class is indexed out at runtime so
    # the match site never sees a literal class (defeats constant-folding).
    classes: list[PyClass] = [];
    classes.append(base_cls);  # index 0
    classes.append(mid_cls);  # index 1
    classes.append(leaf_cls);  # index 2
    classes.append(sib_cls);  # index 3
    raise_idx: list[int] = [2, 2, 3, 2];  # Leaf, Leaf, Sib, Leaf

    # Scenario A -- BASE match (not exact): table [Mid->20, Base->10], raise Leaf.
    # Mid is a base of Leaf two levels up, and is the FIRST arm -> handler 20.
    tblA: list[PyExcArm] = [];
    tblA.append(make_arm(mid_cls, 20));
    tblA.append(make_arm(base_cls, 10));

    # Scenario B -- ARM-ORDER precedence: table [Base->10, Mid->20], raise Leaf.
    # BOTH Base and Mid are in Leaf's MRO; the earlier broad Base arm must win
    # (10), proving first-match, not best/most-derived (which would pick Mid=20).
    tblB: list[PyExcArm] = [];
    tblB.append(make_arm(base_cls, 10));
    tblB.append(make_arm(mid_cls, 20));

    # Scenario C -- NO match: table [Mid->20] only, raise Sib. Mid is not in
    # MRO(Sib)=[Sib,Base] -> propagate sentinel (-1).
    tblC: list[PyExcArm] = [];
    tblC.append(make_arm(mid_cls, 20));

    # Scenario D -- EXACT match still works and beats a broader later arm: table
    # [Leaf->30, Mid->20], raise Leaf -> Leaf arm is first AND exact -> 30.
    tblD: list[PyExcArm] = [];
    tblD.append(make_arm(leaf_cls, 30));
    tblD.append(make_arm(mid_cls, 20));

    # Raised instances built from the RUNTIME-indexed classes.
    instA = make_inst(classes[raise_idx[0]]);  # Leaf
    instB = make_inst(classes[raise_idx[1]]);  # Leaf
    instC = make_inst(classes[raise_idx[2]]);  # Sib
    instD = make_inst(classes[raise_idx[3]]);  # Leaf

    rA = dispatch_raise(instA, tblA);  # expect 20 (base match)
    rB = dispatch_raise(instB, tblB);  # expect 10 (broad-before-specific wins)
    rC = dispatch_raise(instC, tblC);  # expect -1 (no match -> propagate)
    rD = dispatch_raise(instD, tblD);  # expect 30 (exact)

    # Guard each observed handler_id; a wrong match order / best-match miscompile
    # or a dropped no-match surfaces as a distinct negative sentinel.
    if rA != 20 {
        return -10;
    }
    if rB != 10 {
        return -20;
    }
    if rC != -1 {
        return -30;
    }
    if rD != 30 {
        return -40;
    }

    # Accumulate the observed handler_ids into one encoded total. no_match is
    # recorded as a flag (rC propagated) so it is individually visible.
    no_match_flag = 0;
    if rC == -1 {
        no_match_flag = 1;
    }
    # 20_10_1_30 -> 20*1000000 + 10*10000 + 1*100 + 30 = 20100130.
    return rA * 1000000 + rB * 10000 + no_match_flag * 100 + rD;
}

with entry {
    print(run());
}
