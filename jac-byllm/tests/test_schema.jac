"""
This fixture is to test all cases of schema are supported in jac-byllm.
It is used to ensure that the schema support in jac-byllm works as expected.

NOTE: This file should not be used in CI tests, as it supposed to call OpenAI
API and mocking the API will make the test ineffective.

To run all tests:
  jac test <path-to-this-file>

To run a specific test:
  jac test <path-to-this-file> -t <test-name>
"""

import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini",);

"""
Return true if the given statement meets the expectation.
The statement is a string that describes the condition to be met.
"""
def assert_statement_met_expectation(statement: str, expectation: str,) -> bool by llm();

test assert_statement_met_expectation_working {
    is_true = assert_statement_met_expectation(
        "La météo à Paris est de 22°C et venteux.",
        "The weather in Paris *MUST* match 22 degrees Celsius and windy."
        "And the statement *SHOULD* be in French.",
    );
    assert is_true;
}

# =============================================================================
# Case: Simple object
# =============================================================================
obj Person {
    has name: str,
        age: int,
        description: str | None;
}

def generate_random_person -> Person by llm();

test simple_object {
    person = generate_random_person();
    assert isinstance(person, Person);
    print(
        f"Generated Person: {person.name}, Age: {person.age}, Description: {person.description}"
    );
}

# =============================================================================
# Case: Nested object
# =============================================================================
obj Address {
    has street: str,
        city: str,
        zip_code: str;
}

obj User {
    has username: str,
        email: str,
        address: Address;
}

def generate_random_user -> User by llm();

test nested_object {
    user = generate_random_user();
    assert isinstance(user, User);
    assert isinstance(user.address, Address);
    print(
        f"Generated User: {user.username}, Email: {user.email}, Address: {user.address.street}, {user.address.city}, {user.address.zip_code}"
    );
}

# =============================================================================
# Case: Union types + inheritnace
# =============================================================================
obj Pet {
    has name: str,
        age: int;
}

obj Dog(Pet) {
    has breed: str;
}

obj Cat(Pet) {
    has color: str;
}

obj MyPet {
    has pet: Dog | Cat;
}

def generate_random_pet -> MyPet by llm();

test union_types_and_inheritance {
    pet = generate_random_pet();
    assert isinstance(pet, MyPet);
    print(f"Generated Pet: {pet.pet.name}, Age: {pet.pet.age}");
    if isinstance(pet.pet, Dog) {
        print(f"Breed: {pet.pet.breed}");
    } elif isinstance(pet.pet, Cat) {
        print(f"Color: {pet.pet.color}");
    }
}

# =============================================================================
# Case: Primitive return types
# =============================================================================

# Since OpenAI donesn't support primitive at the root level of the schema,
# we'll need to wrap them in an object.
def is_statement_true(statement: str) -> bool by llm();

test bool_return {
    # Should be true.
    statement = "The sky is blue";
    is_true = is_statement_true(statement);
    print(f"Statement {statement} is {is_true}");
    assert isinstance(is_true, bool);
    assert is_true == True;

    # Should be false.
    statement = "1 + 1 = 3";
    is_true = is_statement_true(statement);
    print(f"Statement {statement} is {is_true}");
    assert isinstance(is_true, bool);
    assert is_true == False;
}

# =============================================================================
# Case: Enum (auto/int)
# =============================================================================
enum Color {
    Red,
    Green,
    Blue,
}

def get_random_color -> Color by llm();

test enum_case {
    color = get_random_color();
    assert isinstance(color, Color);
    print(f"Generated Color: {color}");
    assert color in Color.__members__.values() , f"Color {color} is not a valid Color";
}

# =============================================================================
# Case: Enum (string)
# =============================================================================
enum WeatherCondition {
    Sunny = "Sunny",
    Cloudy = "Cloudy",
    Rainy = "Rainy",
    Windy = "Windy",
}

def get_random_weather_condition -> WeatherCondition by llm();

test enum_string_case {
    condition = get_random_weather_condition();
    assert isinstance(condition, WeatherCondition);
    print(f"Generated Weather Condition: {condition}");
    assert condition in WeatherCondition.__members__.values() , f"Condition {condition} is not a valid WeatherCondition";
    assert isinstance(condition.value, str) , f"Condition value {condition.value} is not a string";
}

# =============================================================================
# Case: Test tool schema
# =============================================================================
obj WeatherData {
    has city: str,
        temperature: float,
        condition: str;
}

def get_weather(city: str) -> WeatherData {
    print(f"Fetching weather data for {city}...");
    if (city.lower() == "london") {
        return WeatherData(city="London", temperature=20.0, condition="Sunny");
    }
    if (city.lower() == "new york") {
        return WeatherData(city="New York", temperature=25.0, condition="Cloudy");
    }
    if (city.lower() == "tokyo") {
        return WeatherData(city="Tokyo", temperature=30.0, condition="Rainy");
    }
    if (city.lower() == "paris") {
        return WeatherData(city="Paris", temperature=22.0, condition="Windy");
    }
    return WeatherData(city=city, temperature=0.0, condition="Unknown");
}

# Althought this is an llm function, we'll use it as a tool.
def translate_from_english(
    to_language: str, sentence: str
) -> str by llm();

def answer_user(question: str) -> str by llm(
    tools=[get_weather, translate_from_english],
);

test tool_functionality {
    statement = answer_user("Tell me the weather in paris in French.");
    assert assert_statement_met_expectation(
        statement,
        "The weather in Paris *MUST* match 22 degrees Celsius and windy."
        "And the statement *SHOULD* be in French.",
    );
}

# =============================================================================
# Case: Semstrings attached in schema
# =============================================================================
obj Client {
    has name: str,
        major: str;
}

sem Client.name = "Should always be 'Alice'";
sem Client.major = "Should always be 'Legal Advisor'";

def generate_client -> Client by llm();

test semstrings_attached_in_schema {
    client = generate_client();
    assert isinstance(client, Client);
    assert client.name == "Alice";
    assert client.major == "Legal Advisor";
    print(f"Generated Client: {client.name}, Major: {client.major}");
}

# =============================================================================
# Case: Annotated list
# =============================================================================
def get_first_n_numbers_of_fibonacci(
    n: int
) -> list[int] by llm();

test annotated_list {
    n = 10;
    fibonacci_numbers = get_first_n_numbers_of_fibonacci(n);
    print(f"FibonacciNumbers({n}) = {fibonacci_numbers}");

    assert isinstance(fibonacci_numbers, list);
    assert all([isinstance(num, int) for num in fibonacci_numbers]);

    expected = [0, 1, 1, 2, 3, 5, 8, 13, 21, 34];
    assert fibonacci_numbers == expected , f"Expected {expected}, but got {fibonacci_numbers}";
}

# =============================================================================
# Case: Annotated tuple (with ellipsis)
# =============================================================================

# This is to ensure that the schema is recursively generated correctly.
obj ColorContainer {
    has colors: tuple[str, ...];
}

def generate_random_colors -> ColorContainer by llm();

test annotated_tuple {
    container = generate_random_colors();
    print(f"Generated ColorContainer: {container}");
    assert isinstance(container, ColorContainer);

    colors = container.colors;
    print(f"Generated Colors: {colors}");

    assert isinstance(colors, tuple);
    assert all([isinstance(color, str) for color in colors]);
    assert len(colors) > 0 , "Expected at least one color";
}

# =============================================================================
# Case: Annotated dictionary
# =============================================================================
def generate_random_name_and_age -> dict[
    str,
    int
] by llm();

sem generate_random_name_and_age.name = "Returns a dictionary with names as keys and ages as values";

test annotated_dictionary {
    name_age_dict = generate_random_name_and_age();
    print(f"Generated Name-Age Dictionary: {name_age_dict}");

    assert isinstance(name_age_dict, dict);
    assert all([isinstance(name, str) for name in name_age_dict.keys()]);
    assert all([isinstance(age, int) for age in name_age_dict.values()]);

    # Check if the dictionary has at least one entry
    assert len(name_age_dict) > 0 , "Expected at least one entry in the dictionary";
}

# =============================================================================
# Case: Recursive dictionary
# =============================================================================
def generate_student_data -> dict[
    str,
    dict[str, int]
] by llm();

sem generate_student_data = """
Returns a dictionary where each key is the class name and value is another
dictionary, where the key is the student's name in that class and value is
their average score.
""";

test recursive_dictionary {
    student_data = generate_student_data();
    print(f"Generated Student Data: {student_data}");

    assert isinstance(student_data, dict);
    assert all([isinstance(class_name, str) for class_name in student_data.keys()]);
    assert all([isinstance(students, dict) for students in student_data.values()]);

    # Check if each student's name is a string and their score is an int
    for (class_name, students) in student_data.items() {
        assert all([isinstance(name, str) for name in students.keys()]);
        assert all([isinstance(score, int) for score in students.values()]);
    }
}
