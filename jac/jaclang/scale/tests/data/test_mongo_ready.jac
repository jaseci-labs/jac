import os;
import from jaclang.scale.persistence.db { _wait_mongo_ready }
import from jaclang.scale._optdeps.pymongo { PyMongoError }


obj _FlakyAdmin {
    has fails: int = 2,
        calls: int = 0;

    def command(name: str) -> str {
        self.calls += 1;
        if self.calls <= self.fails {
            raise PyMongoError("auth not ready yet");
        }
        return "ok";
    }
}


obj _FlakyClient {
    has admin: _FlakyAdmin = _FlakyAdmin();
}


test "first mongo handshake retries through the TCP-up/auth-not-ready window" {
    saved = os.environ.get("JAC_SCALE_RUNTIME");
    os.environ["JAC_SCALE_RUNTIME"] = "1";
    try {
        client: any = _FlakyClient();
        _wait_mongo_ready(client, tries=5, delay=0.01);
        assert client.admin.calls == 3;

        hopeless: any = _FlakyClient(admin=_FlakyAdmin(fails=99));
        raised = False;
        try {
            _wait_mongo_ready(hopeless, tries=3, delay=0.01);
        } except PyMongoError {
            raised = True;
        }
        assert raised;
    } finally {
        if saved is None {
            os.environ.pop("JAC_SCALE_RUNTIME", None);
        } else {
            os.environ["JAC_SCALE_RUNTIME"] = saved;
        }
    }
}
