import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o");

obj OddWord {
    has options: list[str],
        reasoning: str,
        result: str;
}

glob examples: list[OddWord] = [
         OddWord(
             options=["skirt", "dress", "pen", "jacket"],
             reasoning="skirt is clothing, dress is clothing, pen is an object, jacket is clothing.",
             result="pen"
         ),
         OddWord(
             options=["Spain", "France", "German", "England", "Singapore"],
             reasoning="Spain, France, England, Singapore is a country, German is a language.",
             result="German"
         ),

     ];

sem examples = "Examples for Picking Odd Word out (Options, Reasoning, Result)";

def odd_word_out_and_reason(options: list[str]) -> OddWord by llm(
    incl_info={"examples": examples}
);

with entry {
    print(
        odd_word_out_and_reason(
            ["Bentley", "Ferrari", "Lamborghini", "Casio", "Toyota"]
        )
    );
}
