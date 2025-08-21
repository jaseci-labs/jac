enum Enum {
    A = "a",
    B = "b",
    C = "c"
}

obj Child {
    has val: int, arr: list[int], json: dict[str, int], enum_field: Enum;
}

obj Parent(Child) {
    has child: Child;
}

obj SavableObject {
    has val: int, arr: list[int], json: dict[str, int], parent: Parent, enum_field: Enum;
}

walker create_custom_object {
    can enter1 with `root entry {
        self.obj = SavableObject(
            val=0,
            arr=[],
            json={},
            parent=Parent(
                val=1,
                arr=[1],
                json={"a": 1},
                child=Child(
                    val=2,
                    arr=[1, 2],
                    json={"a": 1, "b": 2},
                    enum_field = Enum.C
                ),
                enum_field = Enum.B
            ),
            enum_field = Enum.A
        );
        save(self.obj);

        # commit the object to db
        commit(self.obj);
    }

    can exit1 with `root exit {
        # get directly from shelf
        o = _.get_context().mem.__shelf__.get(str(self.obj.__jac__.id)).archetype;
        print(jid(o));
        print(o);
    }
}

walker get_custom_object {
    has object_id: str;

    can enter1 with `root entry {
        try {
            print(&(self.object_id));
        } except Exception as e {
            print(None);
        }
    }
}

walker update_custom_object {
    has object_id: str;

    can enter1 with `root entry {
        savable_object = &(self.object_id);
        savable_object.parent.child.json["c"] = 3;
        savable_object.parent.child.arr.append(3);
        savable_object.parent.child.val = 3;
        savable_object.parent.child.enum_field = Enum.A;
        savable_object.parent.json["b"] = 2;
        savable_object.parent.arr.append(2);
        savable_object.parent.val = 2;
        savable_object.parent.enum_field = Enum.C;
        savable_object.json["a"] = 1;
        savable_object.arr.append(1);
        savable_object.val = 1;
        savable_object.enum_field = Enum.B;
        print(savable_object);
    }
}

walker delete_custom_object {
    has object_id: str;

    can enter1 with `root entry {
        _.destroy([&(self.object_id)]);
    }
}