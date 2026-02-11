# Frequently Asked Questions

Common questions and answers. If you don't see your question below and couldn't find a solution in the docs, ask your question in our [Discord Community](https://discord.gg/6j3QNdtcN6) (We try to answer within 2hrs.)

---

??? question "I updated to the latest Jac/Jaseci PyPI packages and my project won't `jac start` properly."
    - There may be changes to the assumptions of the runtime's `.jac` working directory. Try `jac clean --all` in your project's folder.

??? question "Can ____ be done in Jac? Is ____ compatible with Jac?"
    **Yes**, if the answer to any of these questions is yes:

    - Can it be done in Python with any PyPI package?
    - Can it be done in TypeScript/JavaScript with any Node.js package?
    - Can it be done in C with any C-compatible library?

    Jac compiles to Python (server), JavaScript (client), and native binaries (C ABI), so any library or tool compatible with those ecosystems is compatible with Jac.

    **If you find something that works in Python/Node.js/C but doesn't work in Jac, that's a bug!** Please [file an issue](https://github.com/Jaseci-Labs/jaseci/issues) or let us know in the [Discord](https://discord.gg/6j3QNdtcN6).
