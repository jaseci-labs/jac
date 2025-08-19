<h1 style="color: orange; font-weight: bold; text-align: center;">Tour of Jac</h1>

## Python Superset Philosophy: All of Python Plus More

Jac is a drop-in replacement for Python and supersets Python, much like Typescript supersets Javascript or C++ supersets C. It extends Python's semantics while maintaining full interoperability with the Python ecosystem, introducing cutting-edge abstractions designed to minimize complexity and embrace AI-forward development.

<div class="code-block">
```jac
import math;
import from random { uniform }

def calc_distance(x1: float, y1: float, x2: float, y2: float) -> float {
return math.sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2);
}

with entry { # Generate random points
(x1, y1) = (uniform(0, 10), uniform(0, 10));
(x2, y2) = (uniform(0, 10), uniform(0, 10));

    distance = calc_distance(x1, y1, x2, y2);
    area = math.pi * (distance / 2) ** 2;

    print("Distance:", round(distance, 2), ", Circle area:", round(area, 2));

}

```
</div>

This snippet natively imports Python packages `math` and `random` and runs identically to its Python counterpart. Jac targets Python bytecode, so all Python libraries work with Jac.


## Programming Abstractions for AI

Jac provides novel constructs for integrating LLMs into code. A function body can simply be replaced with a call to an LLM, removing the need for prompt engineering or extensive use of new libraries.

```jac
import from mtllm { Model }
glob llm = Model(model_name="gemini/gemini-2.0-flash");

enum Personality {
    INTROVERT = "Introvert",
    EXTROVERT = "Extrovert",
    AMBIVERT = "Ambivert"
}

def get_personality(name: str) -> Personality by llm();

with entry {
    name = "Albert Einstein";
    result = get_personality(name);
    print(f"{result.value} personality detected for {name}");
}
```

??? info "How To Run"
    1. Install the MTLLM plugin by `pip install mtllm`
    2. Get a free Gemini API key: Visit [Google AI Studio](https://aistudio.google.com/app/apikey)
    3. Save your Gemini API as an environment variable (`export GEMINI_API_KEY="xxxxxxxx"`).
    > **Note:** > > You can use OpenAI, Anthropic or other API services as well as host your own LLM using Ollama or Huggingface.
    4. Copy this code into `example.jac` file and run with `jac run example.jac`

??? example "Output"
    `   Introvert personality detected for Albert Einstein
    `

`by llm()` delegates execution to an LLM without any extra library code.


## Beyond OOP: An Agentic Programming Model

In addtion to traditional python classes (`class` or Jac's dataclass-like `obj`), Jac programmers can also use node classes (`node`), edge classes (`edge`), and walker classes (`walker`) for a new type of problem solving and agentic programming.

Instances of node and edge classes allow for assembling objects in a graph structure to express semantic relationships between objects. This goes beyond only modeling objects in memory as a disconnected soup of instances.

Walker classes inverts the traditional relationship between data and computation. Rather than moving data to computation with parameter passing, walkers enable moving computation to data as they represent computational units that moves through the topology of node and edge objects.

These new constructs gives rise to a new paradigm for problem solving and implementation we call Object-Spatial Programming (OSP).

In this example, nodes represent meaningful entities (like Weights, Cardio Machines), while walkers (agents) traverse these nodes, collect contextual information, and collaborate with an LLM to generate a personalized workout plan.

```jac
import from mtllm.llm {Model}

glob llm = Model(model_name="gemini/gemini-2.5-flash");

node Equipment {}

node Weights(Equipment) {
    has available: bool = False;

    can check with FitnessAgent entry {
        visitor.gear["weights"] = self.available;
    }
}

node Cardio(Equipment) {
    has machine: str = "treadmill";

    can check with FitnessAgent entry {
        visitor.gear["cardio"] = self.machine;
    }
}

node Trainer {
    can plan with FitnessAgent entry {
        visitor.gear["workout"] = visitor.create_workout(visitor.gear);
    }
}

walker FitnessAgent {
    has gear: dict = {};

    can start with `root entry {
        visit [-->(`?Equipment)];
    }

    """Create a personalized workout plan based on available equipment and space."""
    def create_workout(gear: dict) -> str by llm();
}

walker CoachWalker(FitnessAgent) {
    can get_plan with `root entry {
        visit [-->(`?Trainer)];
    }
}

with entry {
    root ++> Weights();
    root ++> Cardio();
    root ++> Trainer();

    agent = CoachWalker() spawn root;
    print("Your Workout Plan:");
    print(agent.gear['workout']);
}
```

??? info "How To Run"
    1. Install the MTLLM plugin by `pip install mtllm`
    2. Save your OpenAI API as an environment variable (`export OPENAI_API_KEY="xxxxxxxx"`).
    > **Note:** > > You can use Gemini, Anthropic or other API services as well as host your own LLM using Ollama or Huggingface.
    4. Copy this code into `example.jac` file and run with `jac run example.jac`

??? example "Output"
    `   Your Workout Plan:
        **Personalized Workout Plan**

        **Duration:** 4 weeks
        **Frequency:** 5 days a week

        **Week 1-2: Building Strength and Endurance**

        **Day 1: Upper Body Strength**
        - Warm-up: 5 minutes treadmill walk
        - Dumbbell Bench Press: 3 sets of 10-12 reps
        - Dumbbell Rows: 3 sets of 10-12 reps
        - Shoulder Press: 3 sets of 10-12 reps
        - Bicep Curls: 3 sets of 12-15 reps
        - Tricep Extensions: 3 sets of 12-15 reps
        - Cool down: Stretching

        **Day 2: Cardio and Core**
        - Warm-up: 5 minutes treadmill walk
        - Treadmill Intervals: 20 minutes (1 min sprint, 2 min walk)
        - Plank: 3 sets of 30-45 seconds
        - Russian Twists: 3 sets of 15-20 reps
        - Bicycle Crunches: 3 sets of 15-20 reps
        - Cool down: Stretching

        **Day 3: Lower Body Strength**
        - Warm-up: 5 minutes treadmill walk
        - Squats: 3 sets of 10-12 reps
        - Lunges: 3 sets of 10-12 reps per leg
        - Deadlifts (dumbbells): 3 sets of 10-12 reps
        - Calf Raises: 3 sets of 15-20 reps
        - Glute Bridges: 3 sets of 12-15 reps
        - Cool down: Stretching

        **Day 4: Active Recovery**
        - 30-45 minutes light treadmill walk or yoga/stretching

        **Day 5: Full Body Strength**
        - Warm-up: 5 minutes treadmill walk
        - Circuit (repeat 3 times):
        - Push-ups: 10-15 reps
        - Dumbbell Squats: 10-12 reps
        - Bent-over Dumbbell Rows: 10-12 reps
        - Mountain Climbers: 30 seconds
        - Treadmill: 15 minutes steady pace
        - Cool down: Stretching

        **Week 3-4: Increasing Intensity**

        **Day 1: Upper Body Strength with Increased Weight**
        - Follow the same structure as weeks 1-2 but increase weights by 5-10%.

        **Day 2: Longer Cardio Session**
        - Warm-up: 5 minutes treadmill walk
        - Treadmill: 30 minutes at a steady pace
        - Core Exercises: Same as weeks 1-2, but add an additional set.

        **Day 3: Lower Body Strength with Increased Weight**
        - Increase weights for all exercises by 5-10%.
        - Add an extra set for each exercise.

        **Day 4: Active Recovery**
        - 30-60 minutes light treadmill walk or yoga/stretching

        **Day 5: Full Body Strength Circuit with Cardio Intervals**
        - Circuit (repeat 4 times):
        - Push-ups: 15 reps
        - Dumbbell Squats: 12-15 reps
        - Jumping Jacks: 30 seconds
        - Dumbbell Shoulder Press: 10-12 reps
        - Treadmill: 1 minute sprint after each circuit
        - Cool down: Stretching

        Ensure to hydrate and listen to your body throughout the program. Adjust weights and reps as needed based on your fitness level.
    `

This MTP example demonstrates how Jac seamlessly integrates LLMs with structured node-walker logic, enabling intelligent, context-aware agents with just a few lines of code.

## Zero to Infinite Scale without any Code Changes

Jac's cloud-native abstractions make persistence and user concepts part of the language so that simple programs can run unchanged locally or in the cloud. Much like every object instance has a self referencial `this` or `self` reference. Every instance of a Jac program invocation has a `root` node reference that is unique to every user and for which any ohter node or edge objeccts connected to `root` will persist across code invocations. Thats it. Using `root` to access presistant user state and data, Jac deployments can be scaled from local enviornments infinitely into to the cloud with no code changes..

```jac
node Post {
    has content: str;
    has author: str;
}

walker create_post {
    has content: str, author: str;

    can func_name with `root entry {
        new_post = Post(content=self.content, author=self.author);
        here ++> new_post;
        report {"id": new_post.id, "status": "posted"};
    }
}
```

??? info "How To Run"
    1. Install the Jac Cloud by `pip install jac-cloud`
    2. Copy this code into `example.jac` file and run with `jac serve example.jac`

??? example "Output"
    `   INFO:     Started server process [26286]
        INFO:     Waiting for application startup.
        INFO - DATABASE_HOST is not available! Using LocalDB...
        INFO - Scheduler started
        INFO:     Application startup complete.
        INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
    `

![Fast API Server](../assets/jac_cloud_example.jpg)


## Better Organized and Well Typed Codebases

Jac focuses on type safety and readability. Type hints are required and the built-in typing system eliminates boilerplate imports. Code structure can be split across multiple files, allowing definitions and implementations to be organized separately while still being checked by Jac's native type system.

=== "tweet.jac"

    ```jac
    obj Tweet {
        has content: str, author: str, timestamp: str, likes: int = 0;

        def like() -> None;
        def unlike() -> None;
        def get_preview(max_length: int) -> str;
        def get_like_count() -> int;
    }
    ```

=== "tweet.impl.jac"

    ```jac
    impl Tweet.like() -> None {
        self.likes += 1;
    }

    impl Tweet.unlike() -> None {
        if self.likes > 0 {
            self.likes -= 1;
        }
    }

    impl Tweet.get_preview(max_length: int) -> str {
        return self.content[:max_length] + "..." if len(self.content) > max_length else self.content;
    }

    impl Tweet.get_like_count() -> int {
        return self.likes;
    }
    ```

    This shows how declarations and implementations can live in separate files for maintainable, typed codebases.

## Next Steps

<div class="grid cards" markdown>

-   __In The Works__

    ---

    *Roadmap Items*

    [In The Roadmap](bigfeatures.md){ .md-button .md-button--primary }

-   __In The Future__

    ---

    *Research in Jac/Jaseci*

    [In Research](research.md){ .md-button }

</div>
