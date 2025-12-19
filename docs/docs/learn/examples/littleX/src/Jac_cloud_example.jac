import from jac_cloud { FastAPI }

walker post_no_body {}

walker post_with_body {
    has a: str;
}

walker get_no_body {
    obj __specs__ {
        static has methods: list = ["get"];
    }
}

walker get_with_query {
    has a: str;

    obj __specs__ {
        static has methods: list = ["get"],
            as_query: list = ["a"];
    }
}

walker get_all_query {
    has a: str,
        b: str;

    obj __specs__ {
        static has methods: list = ["get"],
            as_query: list = "*",
            auth: bool = False;
    }
}

walker post_path_var {
    has a: str;

    obj __specs__ {
        static has path: str = "/{a}",
            methods: list = ["post", "get"];
    }
}

walker combination1 {
    has a: str,
        b: str,
        c: str;

    obj __specs__ {
        static has methods: list = ["post", "get"],
            as_query: list = ["a", "b"];
    }
}

walker combination2 {
    has a: str,
        b: str,
        c: str;

    obj __specs__ {
        static has path: str = "/{a}",
            methods: list = [
                "post",
                "get",
                "put",
                "patch",
                "delete",
                "head",
                "trace",
                "options"
            ],
            as_query: list = ["b"];
    }
}

walker post_with_file {
    has single: UploadFile,
        multiple: list[UploadFile],
        singleOptional: UploadFile | None = None;

    can enter with `root entry {
        print(self.single);
        print(self.multiple);
        print(self.singleOptional);
    }

    obj __specs__ {}
}

walker post_with_body_and_file {
    has val: int,
        single: UploadFile,
        multiple: list[UploadFile],
        optional_val: int = 0;

    can enter with `root entry {
        print(self.val);
        print(self.optional_val);
        print(self.single);
        print(self.multiple);
    }

    obj __specs__ {
        static has auth: bool = False;
    }
}
