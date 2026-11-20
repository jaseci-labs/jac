import from "lucide-react" {
    Bot,
    LoaderCircle,
    CircleCheck,
    CircleSlash,
    CircleAlert,
    ArrowLeft,
    BookOpen,
    Hourglass
}
import from "@jac/runtime" { Link }

glob OUTCOME_LABELS: dict[str, str] = {
         "linked_tutorial": "linked a tutorial",
         "linked_docs": "linked the docs",
         "generated": "wrote a tutorial",
         "gap": "logged a docs gap",
         "ignored": "ignored: not about Jac",
         "throttled": "over today's budget",
         "removed": "post removed",
         "failed": "failed"
     },
     STATE_TEXT: dict[str, str] = {
         "idle": "Idle: waiting for questions",
         "working": "Working on a question",
         "warming": "Warming up",
         "off": "Off"
     };

def:pub NinjaclawTab(model: ClawModel, focus: str) -> JsxElement;

def ClawHeader(model: ClawModel) -> JsxElement;

def OutcomeBadge(job: JobView) -> JsxElement;

def StepList(steps: list[StepView]) -> JsxElement;

def JobRow(job: JobView) -> JsxElement;

def JobDetail(job: JobView) -> JsxElement;

def clock_of(stamp: str) -> str;

def question_of(job: JobView) -> str;
