
import from byllm.lib { MockLLM }
import from os { path }


obj Email {
    has sender: str;
    has subject: str;
    has body: str;
}

# Need to define this after email is defined.
glob llm = MockLLM(
    model_name="mockllm",
    outputs=[
        [
            Email(sender="nora.hartwell@wanderlusttravels.com", subject="Exclusive Offer: 30% Off Your Next Adventure!", body="Pack your bags! We're offering an exclusive 30% discount on all international trips booked this week. Don't miss out on your dream getaway."),
            Email(sender="technews@dailybyte.io", subject="Quantum Leap: The Next Era of Computing", body="Discover how quantum computing is poised to revolutionize everything from cryptography to climate modeling. Read the full article inside."),
            Email(sender="marcus.bentley@fintracker.net", subject="Your Weekly Budget Summary", body="You've spent $342.65 this week. Top categories: Groceries, Transport, and Dining. Click here for a detailed breakdown."),
            Email(sender="claire@novelink.org", subject="Writer's Meetup This Friday", body="Join fellow authors for our biweekly Writer's Circle! Bring your latest piece and get constructive feedback in a cozy, supportive space."),
            Email(sender="support@aetherguard.com", subject="Security Alert: New Login from Unknown Device", body="We detected a login to your account from a new device in Berlin, Germany. If this wasn't you, please reset your password immediately.")
        ],
        "Nora Hartwell from Wanderlust Travels offers a 30% discount on international trips booked this week, urging recipients to take advantage of the limited-time travel deal.",
        "TechNews from DailyByte highlights how quantum computing is set to transform fields like cryptography and climate modeling, with more details in the full article.",
        "Marcus Bentley from FinTracker reports a weekly spending total of $342.65, mainly on Groceries, Transport, and Dining, with a link for detailed insights.",
        "Claire from Novelink invites writers to a biweekly Writer's Circle this Friday for sharing work and receiving feedback in a supportive environment.",
        "AetherGuard reports a login to your account from a new device in Berlin and advises a password reset if the activity was unauthorized.",
    ],
);


def generate_random_mails() -> list[Email] by llm();
sem generate_random_mails =  "Generate 5 random emails.";


def summerize_email(email: Email) -> str
    by llm();
sem summerize_email = "Gets an email instance and summerize the mail and return.";


with entry {
    emails = generate_random_mails();
    for email in emails {
        print(f"Sender: {email.sender}");
        print(f"Subject: {email.subject}");
        print(f"Body: {email.body}");
        print("Summary:", summerize_email(email));
        print('-' * 30);
    }
}

