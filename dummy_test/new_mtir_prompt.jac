import from jaclang.byllm.lib { MockLLM }

glob llm = MockLLM(
         model_name="mockllm",
         config={
             "outputs": ["Good morning, Ada — take it easy today."],
             "verbose": True,
             "show_params": False
         }
     );

enum Mood { CALM = 1, TENSE = 2, EXCITED = 3 }
sem Mood = "The mood type describing emotional state.";
sem Mood.CALM = "Relaxed, at ease, unhurried.";
sem Mood.TENSE = "On edge, anxious, keyed up.";
sem Mood.EXCITED = "Energized, eager, enthusiastic.";

obj Person {
    has full_name: str,
        mood: Mood;
}

sem Person = "A person record with a name and mood.";
sem Person.full_name = "The person's full name.";
sem Person.mood = "The person's current mood.";

def greet(channel: str, person: Person, tone: Mood) -> str by llm();
sem greet = "Write a one-line greeting tailored to the person and the desired tone.";
sem greet.channel = "The delivery channel, e.g. 'email' or 'sms'.";
sem greet.person = "The person to greet.";
sem greet.tone = "How the greeting should feel.";

with entry {
    greet("email", Person(full_name="Ada Lovelace", mood=Mood.CALM), Mood.CALM);
}
