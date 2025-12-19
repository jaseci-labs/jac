import from byllm.lib { Model, Image }

glob llm = Model(model_name="gpt-4o");

obj PurchasedItem {
    has name: str,
        price: float,
        quantity: int;
}

obj Receipt {
    has store: str,
        date: str,
        items: list[PurchasedItem],
        total: float;

    def pp -> None {
        print(f"Store: {self.store}");
        print(f"Date: {self.date}");
        for item in self.items {
            print(f"{item.name} - {item.price} x {item.quantity}");
        }
        print(f"Total: {self.total}");
    }
}

def get_reciept(reciept_img: Image) -> Receipt by llm();
def verity_total(reciept: Receipt) -> bool by llm();

glob
    reciept_img = Image.open("receipt.jpg"),
    receipt = get_reciept(reciept_img);

with entry {
    receipt.pp();
    print(f"Total is correct: {verity_total(receipt)}");
}
