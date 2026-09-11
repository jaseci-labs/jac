"""Typed-output retry: what byLLM does when a reply will not parse.

A non-`str` return that fails to convert is regenerated with corrective feedback,
up to `max_output_retries`. A `str` return is never retried, and an error that is
not a conversion failure propagates untouched.
"""

import asyncio;
import os;
import from pathlib { Path }
import from jaclang.byllm.config_loader { get_byllm_config, reset_byllm_config }
import from support_tests { FakeLLM, fail, prompt_text, say }

glob FIXTURE_DIR: str = os.path.join(os.path.dirname(__file__), "fixtures");


obj RetryPerson {
    has name: str,
        age: int;
}


glob _arecover = FakeLLM(
         replies=[
             say('{"name": "Zoe", "age":'),
             say('{"schema_object_wrapper": {"name": "Zoe", "age": 27}}')
         ]
     );

async def _aget_person -> RetryPerson by _arecover();


test "broken json is regenerated, and the retry prompt shows what was wrong" {
    llm = FakeLLM(
        replies=[
            say('{"name": "Ada", "age":'),
            say('{"schema_object_wrapper": {"name": "Ada", "age": 36}}')
        ]
    );

    def get_person -> RetryPerson by llm();

    for (why, person, model, name, age) in [
        ("sync", get_person(), llm, "Ada", 36),
        ("async", asyncio.run(_aget_person()), _arecover, "Zoe", 27)
    ] {
        assert (person.name, person.age) == (name, age) , (
            f"{why}: malformed then valid JSON should recover, got {person!r}"
        );
        assert len(model.seen) == 2 , (
            f"{why}: expected one retry, got {len(model.seen)} attempts"
        );
        retry = prompt_text(model, 1);
        assert f'"name": "{name}", "age":' in retry , (
            f"{why}: the retry prompt must show the model its broken output"
        );
        assert "age" in retry , f"{why}: the retry prompt must re-show the schema";
    }
}


test "retries are bounded, and the error reports how many were spent" {
    # (label, max_output_retries, expected attempts)
    for (label, call_params, attempts, retries) in [
        ("default limit", {}, 4, 3),
        ("instance limit of 1", {"max_output_retries": 1}, 2, 1)
    ] {
        llm = FakeLLM(replies=[say(f"nope-{i}") for i in range(6)]);

        def get_person -> RetryPerson by llm(**call_params);

        err: any = None;
        try {
            get_person();
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
    }
}


test "only a conversion failure is retried" {
    # A ValueError from the model is not a parse problem, so it propagates on
    # the first attempt rather than burning the retry budget.
    boom = FakeLLM(replies=[fail(ValueError("boom")), say("never reached")]);

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
    empty = FakeLLM(replies=[say("")]);

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
