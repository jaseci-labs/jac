"""Example of simple walker walking nodes."""
import sys;
import from jaclang.lib { Walker, get_context, destroy, reset_graph, perm_grant, perm_revoke, log_report }
import from jac_cloud.core.context {JaseciContext}
import from jac_cloud.jaseci.models {User as BaseUser, NO_PASSWORD}
import from jac_cloud.jaseci.utils {SendGridEmailer}
import from jac_cloud.plugin {WEBSOCKET_MANAGER as socket}
import from jac_cloud.plugin.implementation {create_task}
import from dataclasses {dataclass}
import from fastapi {UploadFile}
import from fastapi.responses {HTMLResponse, StreamingResponse}
import from typing {Any}

class User(BaseUser) {
    has name: str;

    class Collection(BaseUser.Collection) {
        ::py::
        @classmethod
        def __document__(cls, doc) -> "User":
            return User(
                id=doc.pop("_id"),
                email=doc.pop("email"),
                password=doc.pop("password", None) or NO_PASSWORD,
                root_id=doc.pop("root_id"),
                **doc,
            )
        ::py::
    }

    static def send_verification_code(code: str, email: str) -> None {
        SendGridEmailer.send_verification_code(code, email);
    }

    static def send_reset_code(code: str, email: str) -> None {
        SendGridEmailer.send_reset_code(code, email);
    }

    static def sso_mapper(open_id: object) -> dict[str, object] {
        return {
            "name": f"{open_id.first_name} {open_id.last_name}"
        };
    }

    static def system_admin_default() -> dict[str, object] {
        return {
            "name": f"System Administrator"
        };
    }
}

enum Enum {
    A = "a",
    B = "b",
    C = "c"
}

node A {
    has val: int;
}

node B {
    has val: str | int;
}

node C {
    has val: Any;
}

obj Child {
    has val: int, arr: list[int], data: dict[str, int], enum_field: Enum;
}

obj Parent(Child) {
    has child: Child;
}

node Nested {
    has val: int, arr: list[int], data: dict[str, int], parent: Parent, enum_field: Enum, access: str | None = None;

    def __jac_access__ {
        return self.access;
    }
}

obj Kid {
    has enum_field: Enum;
}

obj Adult(Kid) {
    has kid: Kid, arr: list[Kid], data: dict[str, Kid];
}

walker create_graph {
    can enter_root with `root entry {
        a = A(val=0);
        b = B(val=1);
        c = C(val=2);
        a ++> b;
        b ++> c;
        here ++> a;

        report here;
        report a;
        report b;
        report c;
    }
}

walker traverse_graph {
    can enter with `root entry {
        report here;
        visit [-->];
    }

    can enter_A with A entry {
        report here;
        visit [-->];
    }

    can enter_B with B entry {
        report here;
        visit [-->];
    }

    can enter_C with C entry {
        report here;
    }
}

walker detach_node {
    can enter with `root entry {
        visit [-->];
    }

    can enter_A with A entry {
        visit [-->];
    }

    can enter_B with B entry {
        report here del --> [-->];
    }
}

walker update_graph {
    can enter with `root entry {
        report here;
        visit [-->];
    }

    can enter_A with A entry {
        here.val = 1;
        report here;
        visit [-->];
    }

    can enter_B with B entry {
        here.val = 2;
        report here;
        visit [-->];
    }
}

walker create_nested_node {
    can enter_root with `root entry {
        n = Nested(
            val=0,
            arr=[],
            data={},
            parent=Parent(
                val=1,
                arr=[1],
                data={"a": 1},
                child=Child(
                    val=2,
                    arr=[1, 2],
                    data={"a": 1, "b": 2},
                    enum_field = Enum.C
                ),
                enum_field = Enum.B
            ),
            enum_field = Enum.A
        );
        here ++> n;
        report n;
    }
}

walker update_nested_node {
    can enter_root with `root entry {
        nested = [-->(`?Nested)][0];
        nested.parent.child.data["c"] = 3;
        nested.parent.child.arr.append(3);
        nested.parent.child.val = 3;
        nested.parent.child.enum_field = Enum.A;
        nested.parent.data["b"] = 2;
        nested.parent.arr.append(2);
        nested.parent.val = 2;
        nested.parent.enum_field = Enum.C;
        nested.data["a"] = 1;
        nested.arr.append(1);
        nested.val = 1;
        nested.enum_field = Enum.B;
        report nested;
    }

    can enter_nested with Nested entry {
        here.parent.child.data["c"] = 3;
        here.parent.child.arr.append(3);
        here.parent.child.val = 3;
        here.parent.child.enum_field = Enum.A;
        here.parent.data["b"] = 2;
        here.parent.arr.append(2);
        here.parent.val = 2;
        here.parent.enum_field = Enum.C;
        here.data["a"] = 1;
        here.arr.append(1);
        here.val = 1;
        here.enum_field = Enum.B;
        report here;
    }
}

walker update_nested_node_access {
    has access: str | None = None;

    can enter_nested with Nested entry {
        here.access = self.access;
        report here;
    }
}

walker detach_nested_node {
    can enter_root with `root entry {
        report here del--> [-->(`?Nested)];
    }
}

walker update_nested_node_trigger_save {
    can enter_nested with Nested entry {
        here.parent.child.data["c"] = 3;
        here.parent.child.arr.append(3);
        here.parent.child.val = 3;
        here.parent.child.enum_field = Enum.A;
        here.parent.data["b"] = 2;
        here.parent.arr.append(2);
        here.parent.val = 2;
        here.parent.enum_field = Enum.C;
        here.data["a"] = 1;
        here.arr.append(1);
        here.val = 1;
        here.enum_field = Enum.B;

        save(here);
    }
}

walker visit_nested_node {
    can enter_root with `root entry {
        nesteds = [-->(`?Nested)];
        if nesteds {
            report [-->(`?Nested)][0];
        } else {
            report nesteds;
        }
    }

    can enter_nested with Nested entry {
        report here;
    }
}

walker delete_nested_node {
    can enter_root with `root entry {
        nested = [-->(`?Nested)][0];
        destroy(nested);
        report [-->(`?Nested)];
    }
}

walker delete_nested_edge {
    can enter_root with `root entry {
        nested_edge = [edge -->][0];
        destroy(nested_edge);

        report [-->(`?Nested)];
    }
}

walker allow_other_root_access {
    has root_id: str, level: int | str = 0, via_all: bool = False;

    can enter_root with `root entry {
        if self.via_all {
            perm_grant(here, self.level);
        } else {
            perm_grant(here, self.level);
        }
    }

    can enter_nested with Nested entry {
        if self.via_all {
            perm_grant(here, self.level);
        } else {
            perm_grant(here, self.level);
        }
    }
}

walker disallow_other_root_access {
    has root_id: str, via_all: bool = False;

    can enter_root with `root entry {
        if self.via_all {
            revoke(here);
        } else {
            revoke(here);
        }
    }

    can enter_nested with Nested entry {
        if self.via_all {
            revoke(here);
        } else {
            revoke(here);
        }
    }
}

#################################################################
#                    ENDPOINT CUSTOMIZATIONS                    #
# ------------------------------------------------------------- #

walker post_no_body {}

walker post_with_body {
    has a: str;
}

walker get_no_body {
    class __specs__ {
        has methods: list = ["get"];
    }
}

walker get_with_query {
    has a: str;

    class __specs__ {
        has methods: list = ["get"], as_query: list = ["a"];
    }
}

walker get_all_query {
    has a: str;
    has b: str;

    class __specs__ {
        has methods: list = ["get"], as_query: list = "*", auth: bool = False;
    }
}

walker post_path_var {
    has a: str;

    class __specs__ {
        has path: str = "{a}", methods: list = ["post", "get"];
    }
}

walker post_custom_path {
    class __specs__ {
        has path: str = "/custom/walker/path", methods: list = ["post"];
    }
}

walker post_all_excluded {
    has a: str = "";
    has b: str = "";

    class __specs__ {
        has excluded: str = "*", auth: bool = False;
    }
}

walker post_partial_excluded {
    has a: str;
    has b: str = "";

    class __specs__ {
        has excluded: str = "b";
    }
}

walker combination1 {
    has a: str;
    has b: str;
    has c: str;
    has d: str = "";

    class __specs__ {
        has methods: list = ["post", "get"], as_query: list = ["a", "b"], excluded: str = "d";
    }
}


walker combination2 {
    has a: str;
    has b: str;
    has c: str;
    has d: str = "";
    has e: str = "";

    class __specs__ {
        has path: str = "{a}",
        methods: list = ["post", "get", "put", "patch", "delete", "head", "trace", "options"],
        as_query: list = ["b"],
        excluded: list = ["d", "e"];
    }
}

walker post_with_file {
    has single: UploadFile;
    has multiple: list[UploadFile];
    has singleOptional: UploadFile | None = None;


    can enter with `root entry {
        print(self.single);
        print(self.multiple);
        print(self.singleOptional);

        multiple = [];
        for file in self.multiple {
            multiple.append({
                "name": file.filename,
                "content_type": file.content_type,
                "size": file.size,
            });
        }

        single = {
            "single": {
                "name": self.single.filename,
                "content_type": self.single.content_type,
                "size": self.single.size,
            }
        };

        report {
            "single": single,
            "multiple": multiple,
            "singleOptional": self.singleOptional
        };
    }

    class __specs__ {}
}

walker post_with_body_and_file {
    has val: int;
    has single: UploadFile;
    has multiple: list[UploadFile];
    has optional_val: int = 0;

    can enter with `root entry {
        print(self.val);
        print(self.optional_val);
        print(self.single);
        print(self.multiple);
    }

    class __specs__ {
        has auth: bool = False;
    }
}

walker custom_status_code {
    has status: int;

    can enter with `root entry {
        get_context().status = self.status;
    }
}

impl detach_nested_node.enter_root {
    report here del--> [-->(`?Nested)];
}

impl visit_nested_node.enter_root {
    nesteds = [-->(`?Nested)];
    if nesteds {
        report [-->(`?Nested)][0];
    } else {
        report nesteds;
    }
}

impl visit_nested_node.enter_nested {
    report here;
}

walker manual_create_nested_node {
    can enter_root with `root entry {
        n = Nested(
            val=0,
            arr=[],
            data={},
            parent=Parent(
                val=1,
                arr=[1],
                data={"a": 1},
                child=Child(
                    val=2,
                    arr=[1, 2],
                    data={"a": 1, "b": 2},
                    enum_field = Enum.C
                ),
                enum_field = Enum.B
            ),
            enum_field = Enum.A
        );
        here ++> n;
        commit(here);

        # simulate no auto save
        jsrc = get_context().mem;
        jsrc.__mem__.clear();
        jsrc.__gc__.clear();

        report n;
    }
}

walker manual_update_nested_node {
    can enter_root with `root entry {
        nested = [-->(`?Nested)][0];
        nested.parent.child.data["c"] = 3;
        nested.parent.child.arr.append(3);
        nested.parent.child.val = 3;
        nested.parent.child.enum_field = Enum.A;
        nested.parent.data["b"] = 2;
        nested.parent.arr.append(2);
        nested.parent.val = 2;
        nested.parent.enum_field = Enum.C;
        nested.data["a"] = 1;
        nested.arr.append(1);
        nested.val = 1;
        nested.enum_field = Enum.B;
        commit(nested);

        # simulate no auto save
        jsrc = get_context().mem;
        jsrc.__mem__.clear();
        jsrc.__gc__.clear();

        report nested;
    }
}

walker manual_detach_nested_node {
    can enter_root with `root entry {
        nested = [-->(`?Nested)][0];
        detached = here del--> [-->(`?Nested)];
        destroy(nested);
        commit(nested);

        # simulate no auto save
        jsrc = get_context().mem;
        jsrc.__mem__.clear();
        jsrc.__gc__.clear();

        report detached;
    }
}

walker manual_delete_nested_node {
    can enter_root with `root entry {
        nested = [-->(`?Nested)][0];
        destroy(nested);
        commit(nested);

        # simulate no auto save
        jsrc = get_context().mem;
        jsrc.__mem__.clear();
        jsrc.__gc__.clear();

        report [-->(`?Nested)];
    }
}

walker manual_delete_nested_edge {
    can enter_root with `root entry {
        nested_edge = [edge-->][0];
        destroy(nested_edge);
        commit(nested_edge);

        # simulate no auto save
        jsrc = get_context().mem;
        jsrc.__mem__.clear();
        jsrc.__gc__.clear();

        report [-->(`?Nested)];
    }
}

obj CustomResponse {
    has value: int;
}

walker custom_report {
    can enter1 with `root entry {
        report 1;
        report 2;
        report 3;

        log_report(CustomResponse(value=1), True);
    }

    class __specs__ {
        has auth: bool = False, response_model: Any = CustomResponse;
    }
}

walker documentation {
    class __specs__ {
        has response_model: Any = CustomResponse;
        has tags: list[str] | None = ["Documented"];
        has entry_type: EntryType = "root";
        has status_code: int | None = "201";
        has summary: str | None = "Enter summary here!!!";
        has description: str | None = "Enter description here!!!";
        has response_description: str = "Enter response description here!!! Defaults to 'Successful Response'";
        has responses: dict[int | str, dict[str, Any]] | None = {
            200: {
                "description": "Enter response description for http status 200!!!",
                "content": {"application/json": {}},
                "links": {"sample_link": {"description": "Enter link description here!!!"}}
            }
        };
        has deprecated: bool | None = True;
        has name: str | None = "Enter name here!!!";
        has openapi_extra: dict[str, Any] | None = {"addons": True};
    }
}

walker exclude_in_specs {
    class __specs__ {
        has include_in_schema: bool = False;
    }
}

walker html_response {

    class __specs__ {
        has auth: bool = False;
        has methods: list = ["get"];
        has entry_type: str = "ROOT";
    }

    can enter with `root entry {
        html = """<!DOCTYPE html><html lang="en"><body>HELLO WORLD</body></html>""";
        log_report(HTMLResponse(html), custom=True);
    }
}

walker stream_response {

    class __specs__ {
        has auth: bool = False;
        has methods: list = ["get"];
        has entry_type: str = "ROOT";
    }

    can enter with `root entry {
        def generator() -> Generator[str, None, None] {
            for i in range(100) {
                yield str(i);
            }
        }
        log_report(
            StreamingResponse(
                generator(),
                media_type="text/event-stream"
            ),
            custom=True
        );
    }
}

# ------------------------------------------------------------- #
#################################################################

#################################################################
#                           FOR PURGER                          #
# ------------------------------------------------------------- #

node D {
    has id: int;
}

node E {
    has id: int;
}

node F {
    has id: int;
}

node G {
    has id: int;
}

node H {
    has id: int;
}


walker populate_graph {
    can setup1 with `root entry {
        for i in range(2) {
            here ++> D(id=i);
        }
        visit [-->];
    }

    can setup2 with D entry {
        for i in range(2) {
            here ++> E(id=i);
        }
        visit [-->];
    }

    can setup3 with E entry {
        for i in range(2) {
            here ++> F(id=i);
        }
        visit [-->];
    }

    can setup4 with F entry {
        for i in range(2) {
            here ++> G(id=i);
        }
        visit [-->];
    }

    can setup5 with G entry {
        for i in range(2) {
            here ++> H(id=i);
        }
        visit [-->];
    }
}

walker traverse_populated_graph {
    can enter1 with `root entry {
        report here;
        visit [-->];
    }

    can enter2 with D entry {
        report here;
        visit [-->];
    }

    can enter3 with E entry {
        report here;
        visit [-->];
    }

    can enter4 with F entry {
        report here;
        visit [-->];
    }

    can enter5 with G entry {
        report here;
        visit [-->];
    }

    can enter6 with H entry {
        report here;
        visit [-->];
    }
}

walker purge_populated_graph {
    can purge with `root entry {
        report reset_graph();
    }
}

walker check_populated_graph {
    can enter with `root entry {
        import from jac_cloud.core.archetype {NodeAnchor, EdgeAnchor, WalkerAnchor}

        id = here.__jac__.id;
        count = NodeAnchor.Collection.count({"$or": [{"_id": id}, {"root": id}]});
        count += EdgeAnchor.Collection.count({"root": id});
        count += WalkerAnchor.Collection.count({"root": id});

        report count;
    }
}

walker check_memory_sync {
    has other_node_id: str;
    can enter with `root entry {
        import from jac_cloud.core.archetype {NodeAnchor}
        n = &(self.other_node_id);
        n.val = 4;
        report n;
    }
}

# ------------------------------------------------------------- #
#################################################################

#################################################################
#                        SAVABLE OBJECT                         #
# ------------------------------------------------------------- #

obj SavableObject {
    has val: int, arr: list[int], data: dict[str, int], parent: Parent, enum_field: Enum;
}

walker create_custom_object {
    can enter1 with `root entry {
        o = SavableObject(
            val=0,
            arr=[],
            data={},
            parent=Parent(
                val=1,
                arr=[1],
                data={"a": 1},
                child=Child(
                    val=2,
                    arr=[1, 2],
                    data={"a": 1, "b": 2},
                    enum_field = Enum.C
                ),
                enum_field = Enum.B
            ),
            enum_field = Enum.A
        );
        save(o);
        report o;
    }
}

walker get_custom_object {
    has object_id: str;

    can enter1 with `root entry {
        try {
            report &(self.object_id);
        } except Exception as e {
            report None;
        }
    }
}

walker update_custom_object {
    has object_id: str;

    can enter1 with `root entry {
        savable_object = &(self.object_id);
        savable_object.parent.child.data["c"] = 3;
        savable_object.parent.child.arr.append(3);
        savable_object.parent.child.val = 3;
        savable_object.parent.child.enum_field = Enum.A;
        savable_object.parent.data["b"] = 2;
        savable_object.parent.arr.append(2);
        savable_object.parent.val = 2;
        savable_object.parent.enum_field = Enum.C;
        savable_object.data["a"] = 1;
        savable_object.arr.append(1);
        savable_object.val = 1;
        savable_object.enum_field = Enum.B;
        report savable_object;
    }
}

walker delete_custom_object {
    has object_id: str;

    can enter1 with `root entry {
        import from jac_cloud.core.archetype {BaseAnchor}
        destroy(&(self.object_id));

        # This is similar to
        #
        # destroy(BaseAnchor.ref(self.object_id));
        #
        # The only difference is BaseAnchor.ref doesn't
        # load the actual object and just use it as reference
    }
}

walker nested_request_payload {
    has adult: Adult, arr: list[Adult], data: dict[str, Adult], enum_field: Enum;

    can enter1 with `root entry {
        report type(self.adult).__name__;
        report type(self.adult.kid).__name__;
        report type(self.adult.arr[0]).__name__;
        report type(self.adult.data["kid1"]).__name__;
        report type(self.adult.enum_field).__name__;


        report type(self.arr[0]).__name__;
        report type(self.arr[0].kid).__name__;
        report type(self.arr[0].arr[0]).__name__;
        report type(self.arr[0].data["kid1"]).__name__;
        report type(self.arr[0].enum_field).__name__;

        report type(self.data["kid1"]).__name__;
        report type(self.data["kid1"].kid).__name__;
        report type(self.data["kid1"].arr[0]).__name__;
        report type(self.data["kid1"].data["kid1"]).__name__;
        report type(self.data["kid1"].enum_field).__name__;

        report type(self.enum_field).__name__;
    }
}

# ------------------------------------------------------------- #
#################################################################

#################################################################
#                    FOR SPAWN CALL SEQUENCE                    #
# ------------------------------------------------------------- #

node Node {
    has val: str;

    can entry1 with entry {
        report f"{self.val}-2";
    }

    can entry3 with visit_sequence entry {
        report f"{self.val}-3";
    }

    can exit1 with visit_sequence exit {
        report f"{self.val}-4";
    }

    can exit2 with exit {
        report f"{self.val}-5";
    }
}

walker visit_sequence {
    can entry1 with entry {
        report "walker entry";
    }

    can entry2 with `root entry {
        here ++> Node(val = "a");
        here ++> Node(val = "b");
        here ++> Node(val = "c");
        visit [-->];
        report "walker enter to root";
    }

    can entry3 with Node entry {
        report f"{here.val}-1";
    }

    can exit1 with Node exit {
        report f"{here.val}-6";
    }

    can exit2 with exit {
        report "walker exit";
    }

    class __specs__ {
        has auth: bool = False;
    }
}

# ------------------------------------------------------------- #
#################################################################

#################################################################
#                           WEBHOOKS                            #
# ------------------------------------------------------------- #

walker webhook_by_header {
    can enter1 with `root entry {
        report True;
    }

    class __specs__ {
        has webhook: dict = {
            "type": "header",
            "name": "test_key"
        };
    }
}

walker webhook_by_query {
    can enter1 with `root entry {
        report True;
    }

    class __specs__ {
        has webhook: dict = {
            "type": "query",
            "name": "test_key"
        };
    }
}

walker webhook_by_path {
    can enter1 with `root entry {
        report True;
    }

    class __specs__ {
        has webhook: dict = {
            "type": "path",
            "name": "test_key"
        }, path: str = "{test_key}";
    }
}

walker webhook_by_body {
    can enter1 with `root entry {
        report True;
    }

    class __specs__ {
        has webhook: dict = {
            "type": "body",
            "name": "test_key"
        };
    }
}
walker webhook_custom_path {
    can enter1 with `root entry {
        report True;
    }

    class __specs__ {
        has webhook: dict = {
            "type": "body",
            "name": "test_key"
        }, path: str = "/custom/webhook/path";
    }
}

# ------------------------------------------------------------- #
#################################################################

#################################################################
#                           WEBSOCKET                           #
# ------------------------------------------------------------- #

walker websocket {
    has val: int;
    can enter1 with `root entry {
        socket.notify_self({"testing": self.val});
    }

    class __specs__ {
        has methods: list = ["websocket"];
    }
}

# ------------------------------------------------------------- #
#################################################################

#################################################################
#                              TASK                             #
# ------------------------------------------------------------- #

node TaskCounter {
    has val: int = 0;
}

walker get_or_create_counter {
    can enter1 with `root entry {
        tc = TaskCounter();
        here ++> tc;

        report tc;
    }

    can enter2 with TaskCounter entry {
        report here;
    }
}

walker increment_counter {
    has val: int;

    can enter with TaskCounter entry {
        here.val += self.val;
    }

    class __specs__ {
        has private: bool = True;
    }
}

walker trigger_counter_task {
    has id: int;

    can enter with `root entry {
        tcs = [-->(`?TaskCounter)];
        if tcs {
            report create_task(increment_counter(val=1), tcs[0]);
        }

        save(self);
    }
}

# ------------------------------------------------------------- #
#################################################################

#################################################################
#                           SCHEDULER                           #
# ------------------------------------------------------------- #

walker walker_cron {
    has arg1: int;
    has arg2: str;
    has kwarg1: int = 3;
    has kwarg2: str = "4";

    can enter with `root entry {
        import from jac_cloud.core.archetype {NodeAnchor}

        n = NodeAnchor.Collection.find_one({
            "name": "TaskCounter"
        });

        if n {
            report n.archetype.val;
        } else {
            report None;
        }
    }

    class __specs__ {
        has private: bool = True;
        has schedule: dict = {
            "trigger": "cron",
            "args": [1, "2"],
            "kwargs": {
                "kwarg1": 30,
                "kwarg2": "40"
            },
            "save": True,
            "second": "*",
        };
    }
}

# ------------------------------------------------------------- #
#################################################################

#################################################################
#                          ASYNC WALKER                         #
# ------------------------------------------------------------- #

async walker async_walker {
    has arg1: int;
    has arg2: str;
    has kwarg1: int = 3;
    has kwarg2: str = "4";
    has done: bool = False;

    can enter with `root entry {
        self.done = True;
    }
}

# ------------------------------------------------------------- #
#################################################################

#################################################################
#                    DYNAMIC WALKER ENDPOINT                    #
# ------------------------------------------------------------- #

walker generate_walker {

    can enter2 with `root entry {
        report self.__class__.__name__;
    }

    can enter with `root entry {
        type(
            "generated_walker",
            (Walker,),
            {
                "enter": generate_walker.enter2,
                "__specs__": generate_walker.__specs__
            }
        );
    }

    class __specs__ {
        static has auth: bool = False, methods: list = ["get"];
    }
}

# ------------------------------------------------------------- #
#################################################################

with entry:__main__ {
    print("You should not be able to see this log if runned by `jac serve`");
    sys.exit();
    print("This should not be printed!");
}