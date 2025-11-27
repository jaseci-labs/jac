
import from byllm.lib { MockLLM }

glob llm = MockLLM(
    model_name="mockllm",
    outputs=[
        """The orca whale, or killer whale, is one of the most intelligent and adaptable marine predators in the ocean. Renowned for their complex social structures and sophisticated hunting techniques, orcas exhibit remarkable teamwork while pursuing prey. They are found in oceans worldwide, thriving in diverse environments, from icy polar waters to warm coastal regions.\n\nOne of the most striking aspects of orca hunting techniques is their use of cooperative strategies. Orcas often hunt in pods, which can consist of family groups that work together to corral and capture prey. This collaboration may involve creating waves to wash seals off ice floes or employing sophisticated vocalizations to communicate and coordinate efforts. Such teamwork not only increases their chances of a successful hunt but also showcases the social intelligence of these majestic creatures.\n\nOrcas are also known for their varied diets, which can include fish, squid, and even larger marine mammals like seals and whales. Different pods have developed unique hunting techniques tailored to their preferred prey. For instance, some pods specialize in hunting salmon using a technique known as "carousel feeding," where they herd fish into tight balls for easier capture. Others may utilize echolocation to locate prey, demonstrating their advanced sensory capabilities.\n\nIn conclusion, the orca whale's hunting techniques are a testament to their intelligence, adaptability, and social nature. By employing cooperative strategies and showcasing varied dietary preferences, these marine mammals have earned their reputation as apex predators. Their hunting prowess reflects not only their survival instincts but also the intricate social dynamics that define orca pods in the vast oceanic landscape.""",
    ]
);

""" Generate short essay (less than 300 words) about the given topic """
def generate_essay(topic: str) -> str by llm(stream=True);


with entry {
    topic = "The orca whale and its hunting techniques";
    resp = generate_essay(topic);
    assert resp is not str;
    for tok in resp {
        print(tok, end='', flush=True);
    }
    print();
}
