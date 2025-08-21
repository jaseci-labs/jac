import from mtllm { Model }

glob llm = Model(
    model_name="mockllm",
    outputs=["R8@jL3pQ"],
);


def generate_password()  -> str by llm();


sem generate_password= """\
Generates and returns password that:
- contain at least 8 characters
- contain at least one uppercase letter
- contain at least one lowercase letter
- contain at least one digit
- contain at least one special character
""";


with entry {
    password = generate_password();
    print('Generated password:', password);
}
