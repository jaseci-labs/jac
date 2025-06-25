mport from mtllm.llms { OpenAI }
import from PIL { Image }

glob llm = OpenAI(verbose=True, model_name="gpt-4o");

obj 'Purchased Item'
PurchasedItem {
    has name: 'Item Name': str,
        price: 'Item Price': float,
        quantity: 'Item Quantity': int;
}

obj 'Receipt'
Receipt {
    has store: 'Store Name': str,
        date: 'Purchase Date': str,
        items: 'Items': list[PurchasedItem],
        total: 'Total': float;

    def pp() -> None {
        print(f"Store: {self.store}");
        print(f"Date: {self.date}");
        for item in self.items {
            print(f"{item.name} - {item.price} x {item.quantity}");
        }
        print(f"Total: {self.total}");
    }
}

def math_tool(expr: str) -> str {
    return str(eval(expr));
}
sem math_tool = "Evaluate mathematical expressions";
sem math_tool.expr = "Expression to evaluate";

def 'Get Reciept Object'
get_reciept(reciept_img: 'Image of the Receipt': Image) -> 'Reciept Object': Receipt by llm();
def verity_total(reciept: Receipt) -> bool by llm(method="ReAct", tools=[math_tool]);

with entry {
    reciept_img = Image.open("receipt.jpg");
    receipt = get_reciept(reciept_img);
    receipt.pp();
    print(f"Total is correct: {verity_total(receipt)}");
}
