
cl import from "motion/react" { motion }

# ==============   Data   ================
glob food: list = [
    ["🍅", 340, 10],
    ["🍊", 20, 40],
    ["🍋", 60, 90],
    ["🍐", 80, 120],
    ["🍏", 100, 140],
    ["🫐", 205, 245],
    ["🍆", 260, 290],
    ["🍇", 290, 320]
];

# ==============   Styles   ================
glob container: dict = {
    "margin": "100px auto",
    "maxWidth": 500,
    "paddingBottom": 100,
    "width": "100%"
};

glob cardContainer: dict = {
    "overflow": "hidden",
    "display": "flex",
    "justifyContent": "center",
    "alignItems": "center",
    "position": "relative",
    "paddingTop": 20,
    "marginBottom": -120
};

glob splash: dict = {
    "position": "absolute",
    "top": 0,
    "left": 0,
    "right": 0,
    "bottom": 0,
    "clipPath": 'path("M 0 303.5 C 0 292.454 8.995 285.101 20 283.5 L 460 219.5 C 470.085 218.033 480 228.454 480 239.5 L 500 430 C 500 441.046 491.046 450 480 450 L 20 450 C 8.954 450 0 441.046 0 430 Z")'
};

glob card: dict = {
    "fontSize": 164,
    "width": 300,
    "height": 430,
    "display": "flex",
    "justifyContent": "center",
    "alignItems": "center",
    "borderRadius": 20,
    "background": "#f5f5f5",
    "boxShadow": "0 0 1px hsl(0deg 0% 0% / 0.075), 0 0 2px hsl(0deg 0% 0% / 0.075), 0 0 4px hsl(0deg 0% 0% / 0.075), 0 0 8px hsl(0deg 0% 0% / 0.075), 0 0 16px hsl(0deg 0% 0% / 0.075)",
    "transformOrigin": "10% 60%"
};

# ==============   Variants   ================
glob cardVariants: dict = {
    "offscreen": {
        "y": 300
    },
    "onscreen": {
        "y": 50,
        "rotate": -10,
        "transition": {
            "type": "spring",
            "bounce": 0.4,
            "duration": 0.8
        }
    }
};

# ==============   Helper Functions   ================
def hue(h: int) -> str {
    return f"hsl({h}, 100%, 50%)";
}

# ==============   Components   ================

# Card Component
# Props: emoji (str), hueA (int), hueB (int), i (int)
def Card(props: dict) -> any {
    emoji = props["emoji"];
    hueA = props["hueA"];
    hueB = props["hueB"];
    i = props["i"];

    background = f"linear-gradient(306deg, {hue(hueA)}, {hue(hueB)})";

    # Merge splash style with background
    splashStyle = {**splash, "background": background};

    MotionDiv = motion.div;

    return <MotionDiv
        className={f"card-container-{i}"}
        style={cardContainer}
        initial="offscreen"
        whileInView="onscreen"
        viewport={{"amount": 0.8}}
    >
        <div style={splashStyle} />
        <MotionDiv style={card} variants={cardVariants} className="card">
            {emoji}
        </MotionDiv>
    </MotionDiv>;
}

# Main ScrollTriggered Component
def:pub ScrollTriggered() -> any {
    return <div style={container}>
     

        {
            food.map(lambda item:any, i:int -> any {
                emoji = item[0];
                hueA = item[1];
                hueB = item[2];
                return <Card
                    key={emoji}
                    i={i}
                    emoji={emoji}
                    hueA={hueA}
                    hueB={hueB}
                />;
            })
        }
    </div>;
}