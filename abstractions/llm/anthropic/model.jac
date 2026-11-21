"""The standard model: a model behind Anthropic's Messages API, over
HTTP. A request the model's safety classifiers decline re-runs on the API's
default fallback model. The instructions are sent marked for the API's prompt
cache, so the requests of one call, and calls with the same instructions,
read them from it."""

import json;
import time;
import urllib.request;
import from urllib.error { HTTPError }
import from common.contract { Host, Secret }
import from llm.contract {
    ByError,
    ByEvent,
    ByEventKind,
    ByUsage,
    Effort,
    Message,
    Model,
    ModelReply,
    ModelRequest,
    Part,
    PartKind,
    Stop,
}

glob FALLBACK_BETA: str = "server-side-fallback-2026-07-01";

"""`m` as the API takes a message."""
def api_message(m: Message) -> dict[str, any] {
    content: list[any] = [];
    for p in m.parts {
        if p.kind == PartKind.TEXT {
            content.append({"type": "text", "text": p.text});
        } elif p.kind == PartKind.TOOL_CALL {
            content.append({
                "type": "tool_use",
                "id": p.id,
                "name": p.name,
                "input": json.loads(p.input) if p.input != "" else {},
            });
        } elif p.kind == PartKind.KEPT {
            content.append(json.loads(p.text));
        } else {
            result: dict[str, any] = {
                "type": "tool_result",
                "tool_use_id": p.id,
                "content": p.text,
            };
            if p.failed {
                result["is_error"] = True;
            }
            content.append(result);
        }
    }
    return {"role": m.role, "content": content};
}

"""The Message the API's message `m` is: its text and its tool calls, and
what else it holds (its thinking, with its signature) kept as it came."""
def reply_message(m: dict[str, any]) -> Message {
    out = Message(role="assistant");
    content: any = m.get("content", []);
    if isinstance(content, str) {
        out.parts.append(Part(kind=PartKind.TEXT, text=content));
        return out;
    }
    blocks: list[any] = content;
    for b in blocks {
        kind = str(b.get("type", ""));
        if kind == "text" {
            out.parts.append(Part(kind=PartKind.TEXT, text=str(b["text"])));
        } elif kind == "tool_use" {
            out.parts.append(
                Part(
                    kind=PartKind.TOOL_CALL,
                    id=str(b["id"]),
                    name=str(b["name"]),
                    input=json.dumps(b.get("input", {})),
                ),
            );
        } else {
            out.parts.append(Part(kind=PartKind.KEPT, text=json.dumps(b)));
        }
    }
    return out;
}

"""A schema as structured outputs takes it, or None when it leaves something open
(`any`, or a dict), which that can't express."""
def strict_schema(schema: dict[str, any]) -> dict[str, any] | None {
    if len(schema) == 0 or (len(schema) == 1 and "description" in schema) {
        return None;
    }
    out: dict[str, any] = dict(schema);
    if schema.get("type", "") == "object" {
        if "properties" not in schema {
            return None;
        }
        props: dict[str, any] = schema["properties"];
        strict_props: dict[str, any] = {};
        for k in props.keys() {
            p = strict_schema(props[k]);
            if p is None {
                return None;
            }
            strict_props[k] = p;
        }
        out["properties"] = strict_props;
        out["additionalProperties"] = False;
    }
    if schema.get("type", "") == "array" {
        items = strict_schema(schema["items"]);
        if items is None {
            return None;
        }
        out["items"] = items;
    }
    return out;
}

"""The object a result travels in: structured outputs' top level is an object."""
def strict_result(schema: dict[str, any]) -> dict[str, any] | None {
    s = strict_schema(schema);
    if s is None {
        return None;
    }
    return {
        "type": "object",
        "properties": {"result": s},
        "required": ["result"],
        "additionalProperties": False,
    };
}

"""What a reply says its request used."""
def usage_of(reply: dict[str, any], model: str) -> ByUsage {
    used: dict[str, any] = reply.get("usage", {}) or {};
    return ByUsage(
        input_tokens=int(used.get("input_tokens", 0) or 0),
        output_tokens=int(used.get("output_tokens", 0) or 0),
        cache_read_tokens=int(used.get("cache_read_input_tokens", 0) or 0),
        cache_write_tokens=int(used.get("cache_creation_input_tokens", 0) or 0),
        model=str(reply.get("model", model)),
    );
}

obj Anthropic(Model) {
    """The API's key, which is never written down: `ANTHROPIC_API_KEY`
    where the program runs."""
    has key: Secret = Secret(variable="ANTHROPIC_API_KEY"),
        # The model that answers.
        model: str = "claude-sonnet-5-5",
        # Where the API is: a gateway to it, in its place.
        address: str = "https://api.anthropic.com",
        # Seconds one request may take.
        timeout: int = 60,
        # How many times a request the API refuses for load (408, 409, 429,
        # 5xx) or cannot be reached with is made again, after 2, 4, 8 ...
        # seconds.
        retries: int = 0;

    # The API's key, as the program it was opened in gives it: "" where it
    # gives none.
    has given_key: str postinit;

    def postinit {
        self.given_key = "";
    }

    """It takes its key from the program, and reaches the API when it is
    asked (`ask`)."""
    def open(host: dyn Host) {
        self.given_key = host.secret(self.key);
    }

    """One request, made: the API's response to read."""
    def post(body: dict[str, any]) -> any {
        if self.given_key == "" {
            raise ByError(self.key.variable + " isn't set");
        }
        data = json.dumps(body).encode("utf-8");
        attempt = 0;
        while True {
            req = urllib.request.Request(
                self.address.rstrip("/") + "/v1/messages",
                data=data,
                headers={
                    "content-type": "application/json",
                    "x-api-key": self.given_key,
                    "anthropic-version": "2026-10-21",
                    "anthropic-beta": FALLBACK_BETA,
                },
                method="POST",
            );
            try {
                return urllib.request.urlopen(req, timeout=float(self.timeout));
            } except HTTPError as e {
                if not (e.code == 408 or e.code == 409 or e.code == 429 or e.code >= 500)
                    or attempt >= self.retries
                {
                    raise ByError(
                        "the model's API answered " + str(e.code) + ": " + e.read().decode("utf-8")
                    );
                }
            } except OSError as e {
                if attempt >= self.retries {
                    raise ByError("the model's API can't be reached: " + str(e));
                }
            }
            attempt += 1;
            time.sleep(float(2 ** attempt));
        }
    }

    """The reply the API streams on `r`: each piece of its text as a TEXT
    event, then a DONE whose `value` is the whole reply, as the API's
    message."""
    def read_events(r: any) -> Iterator[ByEvent] {
        message: dict[str, any] = {};
        blocks: list[any] = [];
        # (A tool call's input comes as pieces of its JSON, by its block.)
        inputs: dict[int, str] = {};
        used: dict[str, any] = {};
        forever {
            line: bytes = r.readline();
            if len(line) == 0 {
                break;
            }
            text = line.decode("utf-8").strip();
            if not text.startswith("data: ") {
                continue;
            }
            event: dict[str, any] = json.loads(text[6:len(text)]);
            kind = str(event.get("type", ""));
            if kind == "message_start" {
                message = dict(event["message"]);
                used = dict(message.get("usage", {}) or {});
            } elif kind == "content_block_start" {
                block: dict[str, any] = dict(event["content_block"]);
                while len(blocks) <= int(event["index"]) {
                    blocks.append({});
                }
                blocks[int(event["index"])] = block;
                if block.get("type", "") == "tool_use" {
                    inputs[int(event["index"])] = "";
                } elif block.get("type", "") == "thinking" and "thinking" not in block {
                    # (Sent back as it came, with its signature: the model's own
                    # thinking, which may come with no text.)
                    block["thinking"] = "";
                }
            } elif kind == "content_block_delta" {
                at = int(event["index"]);
                delta: dict[str, any] = event["delta"];
                held: dict[str, any] = blocks[at];
                if delta.get("type", "") == "text_delta" {
                    piece = str(delta["text"]);
                    held["text"] = str(held.get("text", "")) + piece;
                    yield ByEvent(kind=ByEventKind.TEXT, text=piece);
                } elif delta.get("type", "") == "input_json_delta" {
                    inputs[at] = inputs[at] + str(delta["partial_json"]);
                } elif delta.get("type", "") == "thinking_delta" {
                    held["thinking"] = str(held.get("thinking", "")) + str(delta["thinking"]);
                } elif delta.get("type", "") == "signature_delta" {
                    held["signature"] = str(held.get("signature", "")) + str(delta["signature"]);
                }
            } elif kind == "content_block_stop" {
                at = int(event["index"]);
                if at in inputs {
                    made: dict[str, any] = blocks[at];
                    made["input"] = json.loads(inputs[at]) if inputs[at] != "" else {};
                }
            } elif kind == "message_delta" {
                change: dict[str, any] = event.get("delta", {}) or {};
                for (k, v) in change.items() {
                    message[k] = v;
                }
                more: dict[str, any] = event.get("usage", {}) or {};
                for (k, v) in more.items() {
                    used[k] = v;
                }
            } elif kind == "error" {
                failed: dict[str, any] = event.get("error", {}) or {};
                raise ByError("the model's API failed: " + str(failed.get("message", failed)));
            } elif kind == "message_stop" {
                break;
            }
        }
        message["content"] = blocks;
        message["usage"] = used;
        yield ByEvent(kind=ByEventKind.DONE, value=message);
    }

    def ask(request: ModelRequest) -> Iterator[ByEvent] {
        system = request.system;
        wrapped = strict_result(request.result_schema)
            if request.result_schema is not None
            else None;
        if wrapped is None and not request.live {
            system += " Reply with only a JSON value, with no other text.";
        }
        body: dict[str, any] = {
            "model": self.model,
            "max_tokens": request.max_tokens,
            # (Said again with every request of the call: kept by the API
            # between them.)
            "system": [{"type": "text", "text": system, "cache_control": {"type": "ephemeral"}}],
            "messages": [api_message(m) for m in request.messages],
            "fallbacks": "default",
        };
        output: dict[str, any] = {};
        if request.effort != Effort.DEFAULT {
            output["effort"] = request.effort.value;
        }
        if wrapped is not None {
            output["format"] = {"type": "json_schema", "schema": wrapped};
        }
        if len(output) > 0 {
            body["output_config"] = output;
        }
        if len(request.tools) > 0 {
            body["tools"] = [
                {"name": t.name, "description": t.doc, "input_schema": t.schema}
                for t in request.tools
            ];
            if request.answer_now {
                body["tool_choice"] = {"type": "none"};
            }
        }
        reply: dict[str, any] = {};
        if request.live {
            body["stream"] = True;
            with self.post(body) as r {
                for event in self.read_events(r) {
                    if event.kind == ByEventKind.DONE {
                        reply = event.value;
                    } else {
                        yield event;
                    }
                }
            }
        } else {
            with self.post(body) as r {
                reply = json.loads(r.read().decode("utf-8"));
            }
        }
        said = reply_message(reply);
        if wrapped is not None {
            # The answer travels in an object, the API's own form for one:
            # the value in it is what was asked for.
            for p in said.parts {
                if p.kind == PartKind.TEXT and p.text.strip().startswith("{") {
                    try {
                        holder: dict[str, any] = json.loads(p.text);
                        if "result" in holder {
                            p.text = json.dumps(holder["result"]);
                        }
                    } except ValueError {
                        # (Not JSON: said as it came, for what asked to refuse.)
                    }
                }
            }
        }
        reason = str(reply.get("stop_reason", ""));
        stop = Stop.END;
        if reason == "refusal" {
            stop = Stop.REFUSED;
        } elif reason == "max_tokens" {
            stop = Stop.MAX_TOKENS;
        } elif reason == "tool_use" {
            stop = Stop.TOOLS;
        }
        yield ByEvent(
            kind=ByEventKind.DONE,
            value=ModelReply(message=said, stop=stop, usage=usage_of(reply, self.model)),
        );
    }
}
