def:pub app -> JsxElement {
    can with entry {
        handle = 1;
        return lambda { print(handle); };
    }
    async can with entry {
        return lambda {};
    }
    can with exit {
        return lambda {};
    }
    return <div/>;
}

def:pub InferredClient -> JsxElement {
    has ticks: int = 0;
    can with entry {
        timer = setInterval(lambda { ticks += 1; }, 1000);
        return lambda { clearInterval(timer); };
    }
    return <div>{ticks}</div>;
}
