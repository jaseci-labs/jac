"""Typed-output retry: what byLLM does when a reply will not parse.

A non-`str` return that fails to convert is regenerated with corrective feedback,
up to `max_output_retries`. A `str` return is never retried, and an error that is
not a conversion failure propagates untouched.
"""

import asyncio;
import from pathlib { Path }
import from jaclang.byllm.config_loader { get_byllm_config, reset_byllm_config }
import from jaclang.byllm.lib { MockLLM }
import from jaclang.byllm.exceptions { OutputConversionError }
import from support { FIXTURE_DIR, fail, prompt_text, say }


obj RetryPerson {
    has name: str,
        age: int;
}


glob _arecover = MockLLM(
         outputs=[
             say('{"name": "Zoe", "age":'),
             say('{"schema_object_wrapper": {"name": "Zoe", "age": 27}}')
         ]
     );

async def _aget_person -> RetryPerson by _arecover();


test "broken json is regenerated, and the retry prompt shows what was wrong" {
    llm = MockLLM(
        outputs=[
            say('{"name": "Ada", "age":'),
            say('{"schema_object_wrapper": {"name": "Ada", "age": 36}}')
        ]
    );

    optional_llm = MockLLM(
        outputs=[say("forty-two"), say('{"schema_object_wrapper": 42}')]
    );
    union_llm = MockLLM(
        outputs=[
            say('{"name": "Bo", "age":'),
            say('{"schema_object_wrapper": {"name": "Bo", "age": 41}}')
        ]
    );

    def get_person -> RetryPerson by llm();
    def maybe_age -> int | None by optional_llm();
    def person_or_age -> RetryPerson | int by union_llm();

    sync_person = get_person();
    async_person = asyncio.run(_aget_person());
    union_person: any = person_or_age();
    # A union return has no usable __name__, so it is retried and named as written.
    for (why, got, expected, model, broken, schema_hint, type_name) in [
        (
            "sync",
            (sync_person.name, sync_person.age),
            ("Ada", 36),
            llm,
            '"name": "Ada", "age":',
            "age",
            "RetryPerson"
        ),
        (
            "async",
            (async_person.name, async_person.age),
            ("Zoe", 27),
            _arecover,
            '"name": "Zoe", "age":',
            "age",
            "RetryPerson"
        ),
        (
            "optional",
            maybe_age(),
            42,
            optional_llm,
            "forty-two",
            "integer",
            "int | None"
        ),
        (
            "union",
            (union_person.name, union_person.age),
            ("Bo", 41),
            union_llm,
            '"name": "Bo", "age":',
            "age",
            "RetryPerson | int"
        )
    ] {
        assert got == expected , (
            f"{why}: malformed then valid JSON should recover, got {got!r}"
        );
        assert len(model.seen) == 2 , (
            f"{why}: expected one retry, got {len(model.seen)} attempts"
        );
        retry = prompt_text(model, 1);
        assert broken in retry , (
            f"{why}: the retry prompt must show the model its broken output"
        );
        assert schema_hint in retry , f"{why}: the retry prompt must re-show the schema";
        assert f"`{type_name}`" in retry , (
            f"{why}: the retry prompt must name the return type as written"
        );
    }
}


test "retries are bounded, and the error reports how many were spent" {
    # (label, max_output_retries, expected attempts, retries, return type)
    for (label, call_params, attempts, retries, type_name) in [
        ("default limit", {}, 4, 3, "RetryPerson"),
        ("instance limit of 1", {"max_output_retries": 1}, 2, 1, "RetryPerson"),
        ("union return", {"max_output_retries": 1}, 2, 1, "int | None")
    ] {
        llm = MockLLM(outputs=[say(f"nope-{i}") for i in range(6)]);

        def get_person -> RetryPerson by llm(**call_params);
        def maybe_age -> int | None by llm(**call_params);

        err: any = None;
        try {
            if type_name == "int | None" {
                maybe_age();
            } else {
                get_person();
            }
        } except Exception as e {
            err = e;
        }
        assert type(err).__name__ == "OutputConversionError" , (
            f"{label}: expected OutputConversionError, got {err!r}"
        );
        assert len(llm.seen) == attempts , (
            f"{label}: expected {attempts} attempts, got {len(llm.seen)}"
        );
        assert f"{attempts} attempt" in str(err) and f"{retries} retries" in str(err) , (
            f"{label}: the error should report the counts, got: {err}"
        );
        assert f"'{type_name}'" in str(err) , f"{label}: the error should name the type, got: {err}";
        assert isinstance(err.__cause__, OutputConversionError) , (
            f"{label}: the last attempt's conversion error must be chained, got {err.__cause__!r}"
        );
        assert isinstance(err.__cause__.__cause__, ValueError) , (
            f"{label}: the JSON parse failure must be chained, got {err.__cause__.__cause__!r}"
        );
    }
}


test "only a conversion failure is retried" {
    # A ValueError from the model is not a parse problem, so it propagates on
    # the first attempt rather than burning the retry budget.
    boom = MockLLM(outputs=[fail(ValueError("boom")), say("never reached")]);

    def get_person -> RetryPerson by boom();

    raised: any = None;
    try {
        get_person();
    } except ValueError as e {
        raised = e;
    }
    assert raised is not None , "a non-conversion error must propagate";
    assert len(boom.seen) == 1 , f"it must not retry, got {len(boom.seen)} attempts";

    # A str return has nothing to convert, so even an empty answer is accepted.
    empty = MockLLM(outputs=[say("")]);

    def get_text -> str by empty();

    assert get_text() == "" , "an empty str answer passes through";
    assert len(empty.seen) == 1 , f"a str return never retries, got {len(empty.seen)}";
}


test "the default retry budget comes from config" {
    reset_byllm_config();
    try {
        cfg = get_byllm_config(Path(FIXTURE_DIR));
        assert cfg.get_call_params_config().get("max_output_retries") == 3 , (
            f"got {cfg.get_call_params_config().get('max_output_retries')}"
        );
    } finally {
        reset_byllm_config();
    }
}
