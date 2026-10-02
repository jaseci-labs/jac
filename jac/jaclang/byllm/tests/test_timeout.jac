"""Non-streaming request timeout: the bound, where it comes from, and its error.

A non-streaming `by llm()` call carries a flat per-request timeout, resolved
from the call site, the model, then `[byllm.call_params]`. A provider that
stalls past it raises `LLMTimeout`, which stays retryable because it is still a
`litellm.Timeout`.
"""

import from jaclang.byllm._optdeps.litellm { litellm }
import from jaclang.byllm.exceptions { LLMTimeout }
import from jaclang.byllm.lib { Model, ModelPool }
import from jaclang.byllm.llm { _is_timeout_error, _is_transient_error }
import from support { mk_run }


test "a non-streaming call carries the configured default bound" {
    model = Model(model_name="gpt-4o-mini");
    params = model.make_model_params(mk_run(stream=False));
    assert params["timeout"] == 600.0 , f"got {params['timeout']!r}";
}


test "the model field overrides the configured default" {
    model = Model(model_name="gpt-4o-mini", timeout=45.0);
    params = model.make_model_params(mk_run(stream=False));
    assert params["timeout"] == 45.0 , f"got {params['timeout']!r}";
}


test "the call site overrides the model" {
    model = Model(model_name="gpt-4o-mini", timeout=45.0);
    params = model.make_model_params(
        mk_run(stream=False, call_params={"timeout": 15.0})
    );
    assert params["timeout"] == 15.0 , f"got {params['timeout']!r}";
}


test "model call_params sit between the call site and the model field" {
    model = Model(model_name="gpt-4o-mini", timeout=45.0);
    model(timeout=30.0);
    params = model.make_model_params(mk_run(stream=False));
    assert params["timeout"] == 30.0 , f"got {params['timeout']!r}";
}


test "a timeout of zero drops the key and restores the provider default" {
    # The escape hatch for a long batch job: no key means litellm resolves its
    # own bound, which is what every non-streaming call did before #9622.
    model = Model(model_name="gpt-4o-mini", timeout=0.0);
    params = model.make_model_params(mk_run(stream=False));
    assert "timeout" not in params , f"got {params.get('timeout')!r}";
}


test "a pool leaves the bound to its router" {
    # ModelPool.postinit hands timeout to the litellm Router, so injecting it
    # per request would set the same value twice by two different routes.
    pool = ModelPool(models=[Model(model_name="gpt-4o-mini")]);
    assert pool._resolve_timeout(mk_run(stream=False)) is None;
    assert "timeout" not in pool.make_model_params(mk_run(stream=False));
}


test "LLMTimeout stays retryable" {
    # _is_transient_error matches litellm.Timeout by isinstance, and the react
    # loop retries in place on it with the tool history intact. A LLMTimeout
    # that broke that inheritance would disable those retries silently.
    err = LLMTimeout(message="provider stalled", model="gpt-4o-mini");
    assert isinstance(err, litellm.Timeout) , "LLMTimeout must remain a litellm.Timeout";
    assert _is_transient_error(err) , "LLMTimeout must stay transient";
    assert str(err) == "provider stalled" , f"got {str(err)!r}";
    assert err.model == "gpt-4o-mini" , f"got {err.model!r}";
}


test "every transport's timeout type is recognised" {
    import httpx;
    assert _is_timeout_error(
        litellm.Timeout(message="stalled", model="gpt-4o-mini", llm_provider="openai")
    ) , "the litellm transport";
    assert _is_timeout_error(httpx.ReadTimeout("stalled")) , "the http_client transport";
    assert not _is_timeout_error(ValueError("not a timeout"));
}
