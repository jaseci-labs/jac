import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o");

obj Essay {
    has essay: str;

    def essay_judge(criteria: str) -> str by llm();
    def generate_summary(judgements: dict) -> str by llm();
    def give_grade(summary: str) -> str by llm();
}

glob essay = "With a population of approximately 45 million Spaniards and 3.5 million immigrants,"
     "Spain is a country of contrasts where the richness of its culture blends it up with"
     "the variety of languages and dialects used. Being one of the largest economies worldwide,"
     "and the second largest country in Europe, Spain is a very appealing destination for tourists"
     "as well as for immigrants from around the globe. Almost all Spaniards are used to speaking at"
     "least two different languages, but protecting and preserving that right has not been"
     "easy for them.Spaniards have had to struggle with war, ignorance, criticism and the governments,"
     "in order to preserve and defend what identifies them, and deal with the consequences.",
     essay = Essay(essay),
     criterias = ["Clarity", "Originality", "Evidence"],
     judgements = {};

with entry {
    for criteria in criterias {
        judgement = essay.essay_judge(criteria);
        judgements[criteria] = judgement;
    }
}

glob summary = essay.generate_summary(judgements),
     grade = essay.give_grade(summary);

with entry {
    print("Reviewer Notes: ", summary);
    print("Grade: ", grade);
}
