def correct_grammar(text: str) -> str by llm(temperature=0.9);

glob files_path = input("Enter the file path to the text file: ");

with entry {
    with open(files_path, 'r') as file {
        text = file.read();
    }
    print("Original text:", text);
}

glob corrected_text = correct_grammar(text);

with entry {
    print("Corrected text:", corrected_text);
}
