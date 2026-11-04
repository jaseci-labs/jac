import from .base_mod { Contract, Step }

obj FirstStep(Step) {
    static has contract: Contract = Contract(weight=3);
}

obj SecondStep(Step) {
    static has contract: Contract = Contract(weight=4);
}
