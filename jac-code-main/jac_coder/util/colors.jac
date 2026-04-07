glob RESET: str = "\033[0m";
glob BOLD: str = "\033[1m";
glob DIM: str = "\033[2m";

glob RED: str = "\033[31m";
glob GREEN: str = "\033[32m";
glob YELLOW: str = "\033[33m";
glob MAGENTA: str = "\033[35m";
glob CYAN: str = "\033[36m";
glob WHITE: str = "\033[97m";

glob AGENT_COLORS: dict = {
         "main": CYAN,
         "build": GREEN,
         "client": GREEN,
         "server": YELLOW,
         "integration": WHITE,
         "plan": CYAN,
         "explore": MAGENTA
     };
