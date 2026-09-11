"""What byLLM puts in the prompt, and what it makes of the reply.

sem strings, incl_info, temperature and receiver state on the way out; typed
returns, enums and scalars on the way back. Assert on both directions.
"""

import os;
import from jaclang { JacRuntimeInterface as Jac }
import from support_tests { FakeLLM, call, prompt_text, roles, say, tool_names, typed }


glob FIXTURE_DIR: str = os.path.join(os.path.dirname(__file__), "fixtures");


enum _Sentiment { POSITIVE, NEGATIVE, NEUTRAL }


enum _LowerPersonality { INTROVERT = "Introvert", EXTROVERT = "Extrovert" }

obj _LowerPerson {
    has full_name: str,
        yod: int,
        personality: _LowerPersonality;
}


enum _MethodPersonality { INTROVERT, EXTROVERT }

obj _MethodPerson {
    has name: str,
        age: int;
}

glob _METHOD_PERSONALITIES: set[_MethodPersonality] = {
         _MethodPersonality.INTROVERT,
         _MethodPersonality.EXTROVERT
     },
     _sem_llm = FakeLLM(replies=[typed(120597), say("R8@jL3pQ")]);


def _generate_specific_number -> int by _sem_llm();

sem _generate_specific_number = "Generates a specific number that is 120597 and returns it.";

def _generate_password -> str by _sem_llm();

sem _generate_password = "Generates a password with an uppercase letter, a digit and a symbol.";


test "incl_info examples and temperature reach the model" {
    emoji_examples: list[dict[(str, str)]] = [
        {
            "input": "I love tp drink pina coladas",
            "output": "\U0001f464\u2764\ufe0f\U0001f964\U0001f34d\U0001f965"
        },
        {"input": "Mime Person", "output": "\U0001f464\U0001f932\U0001f6b7"}
    ];
    llm = FakeLLM(replies=[say("\U0001f464\u27a1\ufe0f\U0001f5fc")]);

    def get_emoji(input: str) -> str by llm(
        temperature=0.7, incl_info={"examples": emoji_examples}
    );

    assert get_emoji("Lets move to paris") == "\U0001f464\u27a1\ufe0f\U0001f5fc";
    sent = llm.seen[0];
    assert sent["temperature"] == 0.7 , f"temperature must reach the model, got {sent.get(
        'temperature'
    )}";
    assert "Mime Person" in str(sent["messages"]) , "incl_info examples must reach the prompt";
}


test "a method's own object reaches the prompt as context" {
    llm = FakeLLM(replies=[typed(86.75)]);

    obj Student {
        has name: str,
            marks: list[int] = [];

        def get_average -> float by llm();
    }
    student = Student(name="Alice", marks=[81, 99, 77, 90]);

    average = student.get_average();
    assert average == 86.75 , f"a float return must be converted, got {average!r}";
    assert isinstance(average, float) , f"expected float, got {type(average).__name__}";
    prompt = prompt_text(llm);
    assert "Alice" in prompt , "the receiver's fields must reach the prompt";
    assert "99" in prompt , f"the marks must reach the prompt: {prompt[:400]}";
}


test "a sem string reaches the prompt and a typed return is converted" {
    number = _generate_specific_number();
    assert number == 120597 , f"expected 120597, got {number!r}";
    assert isinstance(number, int) , (
        f"declared -> int, got {type(number).__name__}: parse_response did not run"
    );
    assert "120597" in prompt_text(_sem_llm) , (
        "the sem string is the prompt; without it the model is told nothing"
    );

    password = _generate_password();
    assert password == "R8@jL3pQ";
    assert "uppercase letter" in prompt_text(_sem_llm, 1) , (
        "each call carries its own sem string"
    );
}


test "a typed object return is parsed, enum member and all" {
    llm = FakeLLM(
        replies=[
            say(
                '{"schema_object_wrapper": {"full_name": "J. Robert Oppenheimer", '
                '"yod": 1967, "personality": "Introvert"}}'
            )
        ]
    );

    def get_person_info(name: str) -> _LowerPerson by llm();

    person = get_person_info("Oppenheimer");
    assert person.full_name == "J. Robert Oppenheimer" , f"got {person!r}";
    assert person.yod == 1967;
    assert person.personality == _LowerPersonality.INTROVERT , (
        f"enum member must be reconstructed, got {person.personality!r}"
    );
    assert "Oppenheimer" in prompt_text(llm) , "the argument must reach the prompt";
}


test "a nested method's incl_info and receiver state reach the prompt" {
    llm = FakeLLM(replies=[typed(_MethodPersonality.INTROVERT.value)]);

    obj _Diarist {
        has diary_entries: list[str];

        def get_personality(person: _MethodPerson) -> _MethodPersonality by llm(
            incl_info={
                "personality_examples": _METHOD_PERSONALITIES,
                "diary_entries": self.diary_entries
            }
        );
    }
    diarist = _Diarist(
        diary_entries=[
            "I won noble prize in Physics",
            "I am popular for my theory of relativity"
        ]
    );

    result = diarist.get_personality(_MethodPerson(name="Albert Einstein", age=76));
    assert result == _MethodPersonality.INTROVERT , f"got {result!r}";

    prompt = prompt_text(llm);
    assert "theory of relativity" in prompt , (
        f"incl_info from the receiver must reach the prompt: {prompt[:400]}"
    );
    assert "Albert Einstein" in prompt , "the argument must reach the prompt";
}


test "an enum return is reconstructed as the member" {
    llm = FakeLLM(replies=[typed(_Sentiment.POSITIVE.value)]);

    def classify(text: str) -> _Sentiment by llm();

    result = classify("I love this!");
    assert result == _Sentiment.POSITIVE , f"got {result!r}";
    assert isinstance(result, _Sentiment) , (
        f"expected a _Sentiment member, got {type(result).__name__}"
    );
    assert "I love this!" in prompt_text(llm);
}


def _wind_speed(city: str) -> str {
    return f"The current wind speed in {city} is about 18-22 km/h.";
}

sem _wind_speed = "Get the current wind speed of a given city.";


"""One tool-using turn, so the recorded params carry a real tools array and a
real tool result. `extra` is merged into the by-llm call params."""
def _wind_report(llm: FakeLLM, extra: dict) -> str {
    answer = "The current wind speed in Puttalam is about 18-22 km/h.";
    llm.replies.extend([call("_wind_speed", {"city": "Puttalam"}), say(answer)]);
    llm.postinit();

    def wind_report(city: str) -> str by llm(tools=[_wind_speed], **extra);

    return wind_report("Puttalam");
}


test "an outgoing request carries the model, messages, tools and response format" {
    llm = FakeLLM();
    _wind_report(llm, {});
    params = llm.seen[0];

    for key in ["model", "messages", "tools", "max_tokens"] {
        assert key in params , f"missing {key} in the outgoing params: {sorted(
            params
        )}";
    }
    assert "temperature" not in params , (
        "temperature must be omitted when the caller never set one, so the provider "
        "applies its own default (issue #7687)"
    );

    # byLLM appends finish_tool whenever the caller passes tools, so a typed
    # answer has a way home.
    assert tool_names(params) == ["_wind_speed", "finish_tool"] , f"got {tool_names(
        params
    )}";
    fn = params["tools"][0];
    assert fn["type"] == "function";
    assert "city" in fn["function"]["parameters"]["properties"] , (
        f"the tool signature must reach the model: {fn['function']['parameters']}"
    );
    assert "wind speed of a given city" in str(fn["function"]) , (
        "the tool's sem string is its description"
    );
}


test "the second turn replays the tool result back to the model" {
    llm = FakeLLM();
    _wind_report(llm, {});
    assert len(llm.seen) == 2 , f"expected a tool turn then an answer turn, got {len(
        llm.seen
    )}";

    assert roles(llm, 1)[:2] == ["system", "user"] , f"got {roles(llm, 1)}";
    tool_msgs = [
        m
        for m in llm.sent("messages")[1]
        if m.get("role") == "tool"
    ];
    assert len(tool_msgs) == 1 , f"expected one tool result, got {len(tool_msgs)}";
    assert tool_msgs[0]["content"]
        == ("The current wind speed in Puttalam is about 18-22 km/h.") , f"got {tool_msgs[
        0
    ]['content']!r}";
}


test "temperature is sent when the caller sets one" {
    llm = FakeLLM();
    _wind_report(llm, {"temperature": 0.3});
    assert llm.seen[0]["temperature"] == 0.3 , f"got {llm.seen[0].get(
        'temperature'
    )!r}";
}


obj TypedPerson {
    has name: str,
        dob: str,
        age: int;
}

obj TypedUniversity {
    has name: str,
        location: str,
        departments: list[TypedUniversity.Department] = [];

    obj Department {
        has name: str,
            head: TypedPerson;
    }
}


test "a nested obj return is parsed, including the obj it nests" {
    # University.Department nests a Person. Both levels have to come back as
    # real instances, and the same call has to work twice.
    person = {"name": "Jason Mars", "dob": "1994-01-01", "age": 30};
    llm = FakeLLM(
        replies=[
            typed({"name": "Albert Einstein", "dob": "14/03/1879", "age": 76}),
            typed({"name": "Computer Science", "head": person}),
            typed({"name": "Computer Science", "head": person})
        ]
    );

    def make_person(name: str) -> TypedPerson by llm();

    def make_department(name: str) -> TypedUniversity.Department by llm();

    einstein = make_person("Albert Einstein");
    assert isinstance(einstein, TypedPerson) , f"got {type(einstein).__name__}";
    assert einstein.dob == "14/03/1879" , f"got {einstein!r}";

    umich = TypedUniversity(name="University of Michigan", location="Ann Arbor");
    for i in range(2) {
        dept = make_department("Computer Science");
        assert isinstance(dept, TypedUniversity.Department) , (
            f"call {i}: got {type(dept).__name__}"
        );
        assert isinstance(dept.head, TypedPerson) , (
            f"call {i}: the nested obj must be an instance too, got {type(
                dept.head
            ).__name__}"
        );
        assert dept.head.name == "Jason Mars" , f"call {i}: got {dept.head!r}";
        umich.departments.append(dept);
    }
    assert len(umich.departments) == 2;
}


obj Email {
    has sender: str,
        subject: str,
        body: str;
}


# `sem` is module-level, so these sit beside their test.
glob _mail_llm = FakeLLM();

def _generate_mails -> list[Email] by _mail_llm();

sem _generate_mails = "Generate 5 random emails.";

def _summarize(email: Email) -> str by _mail_llm();

sem _summarize = "Gets an email instance and summerize the mail and return.";


test "a list-of-obj return parses, and each element feeds the next call" {
    inbox = [
        {
            "sender": "nora@wanderlust.example",
            "subject": "30% Off Your Next Adventure",
            "body": "An exclusive discount on international trips booked this week."
        },
        {
            "sender": "support@aetherguard.example",
            "subject": "New Login from Unknown Device",
            "body": "We detected a login from a new device in Berlin."
        }
    ];
    _mail_llm.replies.extend(
        [typed(inbox), say("A travel discount offer."), say("A security alert.")]
    );
    _mail_llm.postinit();

    mails = _generate_mails();
    assert len(mails) == 2 , f"expected the whole list back, got {len(mails)}";
    for (i, mail) in enumerate(mails) {
        assert isinstance(mail, Email) , (
            f"element {i} must be an Email, got {type(mail).__name__}"
        );
    }
    assert mails[0].sender == "nora@wanderlust.example" , f"got {mails[0]!r}";
    assert "Berlin" in mails[1].body , f"got {mails[1]!r}";

    # Each parsed element goes back out as the argument of the next call, so its
    # fields have to reach that prompt.
    summaries = [_summarize(m) for m in mails];
    assert summaries == ["A travel discount offer.", "A security alert."] , (
        f"got {summaries}"
    );
    assert "30% Off Your Next Adventure" in prompt_text(_mail_llm, 1) , (
        "the email passed in must reach the prompt"
    );
    assert "Berlin" in prompt_text(_mail_llm, 2);
}


test "the model can be any expression, and a bound call keeps its tools" {
    # `by <expr>` takes a model from anywhere, not just a bare name, and a model
    # already bound with tools= keeps that binding.
    ran: list = [];

    """Run Python code and return the output, or the error message."""
    def run_and_test_python_code(code: str) -> str {
        ran.append(code);
        return "Code executed successfully.";
    }
    code = "name = 'Alice'; print(name)";
    # Held by name as FakeLLM: calling one with tools= returns a BaseLLM, which
    # carries no seen/sent, so the recorder needs its own binding.
    text_llm = FakeLLM(replies=[say("Hello, Alice! It is great to see you!")]);
    code_llm = FakeLLM(
        replies=[call("run_and_test_python_code", {"code": code}), say(code)]
    );
    models = {
        "text-gen": text_llm,
        "code-gen": code_llm(tools=[run_and_test_python_code])
    };

    """Generate a greeting for the given person's name."""
    def greeting_text(name: str) -> str by models["text-gen"];

    """Generate python greeting code, running it to check it works."""
    def greeting_code(name: str) -> str by models["code-gen"];

    assert greeting_text("Alice") == "Hello, Alice! It is great to see you!";
    assert tool_names(text_llm.seen[0]) == [] , (
        f"an unbound model sends no tools, got {tool_names(text_llm.seen[0])}"
    );

    assert greeting_code("Alice") == code , "the bound model's answer";
    assert ran == [code] , f"the tool bound in the expression must run, got {ran}";
    assert "run_and_test_python_code" in tool_names(code_llm.seen[0]) , (
        f"got {tool_names(code_llm.seen[0])}"
    );
}


test "a jac.toml system prompt reaches the model, and a per-call one extends it" {
    # The fixture sits beside its own jac.toml because byLLM resolves config
    # from the module's location, so this cannot be done by patching a dict.
    mod = Jac.jac_import(
        "direct_http_model_call",
        base_path=os.path.join(FIXTURE_DIR, "system_prompt_override/")
    )[0];
    llm = FakeLLM(
        replies=[
            say("Hello, Alice! It is great to meet you."),
            say("Hi Alice, welcome!")
        ]
    );
    mod.llm = llm;

    assert mod.say_hello("Alice") == "Hello, Alice! It is great to meet you.";
    base = str(llm.sent("messages")[0][0]);
    assert "You are a friendly assistant" in base , (
        f"the jac.toml system_prompt must reach the model, got {base[:160]!r}"
    );
    assert "three words" not in base , "the per-call prompt must not leak into the first call";

    assert mod.say_hello_brief("Alice") == "Hi Alice, welcome!";
    extended = str(llm.sent("messages")[1][0]);
    assert "You are a friendly assistant" in extended , (
        "a per-call system_prompt extends the base, it does not replace it"
    );
    assert "Respond in three words maximum." in extended , (
        f"the per-call system_prompt is missing, got {extended[:200]!r}"
    );
}
