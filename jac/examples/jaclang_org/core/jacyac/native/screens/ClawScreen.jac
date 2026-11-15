import from "@jac/mobui" { View, Text, Pressable, ScrollView }

obj BodyPart {
    has kind: str,
        text: str;
}

glob CLAW_OUTCOMES: dict[str, str] = {
         "linked_tutorial": "linked a tutorial",
         "linked_docs": "linked the docs",
         "generated": "wrote a tutorial",
         "gap": "logged a docs gap",
         "ignored": "ignored: not about Jac",
         "throttled": "over today's budget",
         "removed": "post removed",
         "failed": "failed"
     };

def:pub ClawScreen -> JsxElement;

def body_parts(body: str) -> list[BodyPart];

def outcome_label(job: JobView) -> str;

def TutorialBody(body: str) -> JsxElement;
