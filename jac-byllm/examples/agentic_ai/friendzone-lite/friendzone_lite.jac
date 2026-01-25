import from byllm { Model, Image }
import from typing { List, Dict, Any }
import os;

def clear_terminal -> None {
    # For Windows
    if os.name == "nt" {
        os.system("cls");  # For macOS / Linux
    } else {
        os.system("clear");
    }
}

glob llm = Model(model_name="gpt-4.1");

obj Response {
    has follow_up_questions: str,
        summary: str,
        when: str,
        who: List[str],
        what: str,
        where: List[str],
        terminate_conversation: bool,
        show_summary: bool;
}

sem Response = "Memory details refined using the user's input and prior context.";
sem Response.follow_up_questions = "Ask one follow-up question to continue the conversation. If all required details are present, ask to terminate the conversation.";
sem Response.summary = "A concise summary of the memory.";
sem Response.when = "The date of the memory in YYYY-MM-DD format.";
sem Response.who = "Exact names of people in the memory (e.g., [John, Kate]); return [] if none.";
sem Response.where = "List of places relevant to the memory.";
sem Response.what = "What the memory is about.";
sem Response.show_summary = "True if all required details are present and the summary should be shown.";
sem Response.terminate_conversation = "True if the user asked to terminate the conversation; otherwise false.";

""" Update and extract memory details based on user input and context."""
def update_memory_details(
    image: Image,
    utterance: str = "",
    summary: str = "",
    when: str = "",
    who: List[str] = [],
    where: List[str] = [],
    what: str = "",
    conversation: List[dict] = [],
    show_summary: bool = False,
    terminate_conversation: bool = False
) -> Response by llm();

node session {
    has summary: str = "",
        when: str = "",
        who: list = [],
        where: list = [],
        what: str = "",
        conversation: list = [],
        image_url: str = "",
        show_summary: bool = False,
        terminate_conversation: bool = False;
}

walker update_session {
    has image_url: str,
        utterance: str = "";

    can visit_session with `root entry {
        visit [-->](`?session) else {
            session_node = here ++> session();
            visit session_node[0];
        }
    }

    can update_session with session entry {
        if here.image_url == "" {
            here.image_url = self.image_url;
        }
        response = update_memory_details(
            image=Image(url=self.image_url),
            utterance=self.utterance,
            summary=here.summary,
            when=here.when,
            who=here.who,
            where=here.where,
            what=here.what,
            conversation=here.conversation,
            show_summary=here.show_summary,
            terminate_conversation=here.terminate_conversation
        );
        here.summary = response.summary;
        here.when = response.when;
        here.who = response.who;
        here.where = response.where;
        here.what = response.what;
        here.show_summary = response.show_summary;
        self.show_summary = response.show_summary;
        here.terminate_conversation = response.terminate_conversation;
        self.terminate_conversation = response.terminate_conversation;
        here.conversation = here.conversation + [
            {"role": "user", "content": self.utterance}
        ] + [{"role": "assistant", "content": response.follow_up_questions}];

        if response.show_summary {
            if response.terminate_conversation {
                print("🤖 Assistant: " + response.follow_up_questions);
                print("✅ Final Memory Summary:" + response.summary);
            } else {
                print("📝 Memory Summary (in progress):" + response.summary);
                print("🤖 Assistant: " + response.follow_up_questions);
            }
        } else {
            print("🤖 Assistant: " + response.follow_up_questions);
        }

        # Report session state for frontend
        report {
            "summary": here.summary,
            "when": here.when,
            "who": here.who,
            "where": here.where,
            "what": here.what,
            "show_summary": here.show_summary,
            "terminate_conversation": here.terminate_conversation,
            "follow_up_questions": response.follow_up_questions,
            "conversation": here.conversation,
            "image_url": here.image_url
        };
    }
}
# with entry {
#     clear_terminal();
#     print("🚀 Starting Friendzone Lite...");
#     image_url = input("🌐 Please enter an image URL: ");
#     if image_url == "" {
#         print("❌ No image URL provided. Exiting.");
#         exit(1);
#     }
#     walker_obj = root spawn update_session(image_url=image_url);
#     while not (walker_obj.show_summary and walker_obj.terminate_conversation) {
#         utterance = input("👤 You: ");
#         walker_obj = root spawn update_session(utterance=utterance, image_url=image_url);
#     }
# }
