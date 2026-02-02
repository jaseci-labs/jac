# Frequently Asked Questions

Common questions and answers. If you don't see your question below and couldn't find a solution in the docs, ask your question in our [Discord Community](https://discord.gg/6j3QNdtcN6) (We try to answer within 2hrs.)

---

<!-- <a id="define-node-question" style="display: none;"></a> -->
??? question "I updated to the latest Jac/Jaseci PyPI packages and my project won't `jac start` properly."
    - There may be changes to the assumptions of the runtime's `.jac` working directory. Try `jac clean --all` in your project's folder.
