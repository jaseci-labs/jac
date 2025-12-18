import from byllm.lib { Model }

glob llm = Model(host="http://127.0.0.1:11434", model_name="ollama/llama3.2:1b");

"""Summarize latest trends, major events, and notable interactions from the recent tweets in one line."""
def summarise_tweets(tweets: list[str]) -> str by llm();

walker get_summary {
    can out with `root entry {
        Tweets = [
            "Just finished a thrilling book that I couldn't put down! What's your latest page-turner? ",
            "Movie nights are the best! What's a film that you can watch over and over? ",
            "Diving into a new fantasy series this weekend—what genre do you love to escape into? ",
            "Caught the latest blockbuster last night! What's your favorite film of the year so far? ",
            "Nothing like curling up with a good book and a cup of tea. What's your ideal reading setup? ",
            "Just started a new hobby: film photography! What hobbies are you passionate about? ",
            "Books can transport us to different worlds. What fictional universe would you love to live in? ",
            "Anyone else binge-watching classic films lately? What's a must-see that everyone should experience? ",
            "Reading is my escape. What's a book that changed your perspective on life? ",
            "I love discovering indie films! What's an underrated gem you'd recommend? "
        ];
        print(summarise_tweets(Tweets));
    }
}

"""Answer a question based on the provided qusetion parameter."""
def answer_question(question: str) -> str by llm();

# get_summary() spawn root;
with entry {
    print(answer_question("what's 2 + 2"));
}
