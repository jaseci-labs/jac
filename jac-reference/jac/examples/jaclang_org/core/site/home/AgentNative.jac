glob _FN_LINES: list[str] = [
         "enum Priority { LOW, MEDIUM, HIGH, URGENT }",
         "",
         "def assess(ticket: str) -> Priority by llm();",
         "",
         "with entry {",
         "    print(assess(\"Checkout is down!\"));  # Priority.URGENT",
         "}",

     ],
     _OBJ_LINES: list[str] = [
         "obj Concierge {",
         "    has guest: str,",
         "        bookings: list[str] = [];",
         "",
         "    def book(place: str) -> str {",
         "        self.bookings.append(place);",
         "        return \"booked \" + place;",
         "    }",
         "",
         "    def help(request: str) -> str",
         "        by llm(tools=[self.book]);",
         "}",

     ],
     _WALK_LINES: list[str] = [
         "node Page {",
         "    has title: str,",
         "        text: str;",
         "}",
         "",
         "walker Researcher {",
         "    has question: str;",
         "",
         "    can explore with Page entry {",
         "        visit [-->] by llm(select=1,",
         "            intent=\"Follow the most useful link\");",
         "    }",
         "}",

     ],
     _L1: list[dict[str, any]] = [
         {"y": 110, "label": "Shipping", "on": False},
         {"y": 210, "label": "Billing", "on": True},
         {"y": 310, "label": "Accounts", "on": False},

     ],
     _L2: list[dict[str, any]] = [
         {"y": 130, "label": "Invoices", "on": False},
         {"y": 210, "label": "Refund policy", "on": True},
         {"y": 290, "label": "Payment methods", "on": False},

     ];

def:pub FnMini -> JsxElement;

def:pub ObjMini -> JsxElement;

def:pub WalkMini -> JsxElement;

def:pub WalkerDiagram -> JsxElement;

def:pub Rung(
    num: str, title: str, body: str, lines: list[str], file: str, diagram: any = None
) -> JsxElement;

def:pub AgentNative -> JsxElement;
