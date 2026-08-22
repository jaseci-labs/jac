@__jac_value__
obj rotating_tree_enum_fn {
    def call(`node: rotating_node_t, arg: object) -> int {
        ;
    }
}

@__jac_value__
obj rotating_node_t {
    has key: object = object(),
        left: rotating_node_t = rotating_node_t(),
        right: rotating_node_t = rotating_node_t();
}

glob random_value: int = 1,
     random_stream: int = 0,
     random_mutex: int = 0;

def random_lock {
    ;
    random_mutex = 1;
}

def random_unlock {
    ;
    random_mutex = 0;
}

def randombits(bits: int) -> int {
    ;
    result: int = 0;
    random_lock();
    if (random_stream < (1 << bits)) {
        random_value *= 1082527;
        random_stream = random_value;
    }

    result = random_stream & ((1 << bits) - 1);
    random_stream >>= bits;
    random_unlock();
    return result;
}

def RotatingTree_RandomBits(bits: int) -> int {
    return randombits(bits);
}

def RotatingTree_Add(`root: rotating_node_t, `node: rotating_node_t) {
    while (`root != None) {
        if (`node.key < `root.key) {
            `root = `root.left;
        } else {
            `root = `root.right;
        }
    }

    `node.left = None;
    `node.right = None;
    `root = `node;
}

def RotatingTree_Get(`root: rotating_node_t, key: object) -> rotating_node_t {
    if (randombits(3) != 4) {
        `node: rotating_node_t = `root;
        while (`node != None) {
            if (`node.key == key) {
                return `node;
            }
            if (key < `node.key) {
                `node = `node.left;
            } else {
                `node = `node.right;
            }
        }

        return None;
    } else {
        pnode: object = `root;
        `node: rotating_node_t = pnode;
        next: rotating_node_t = rotating_node_t();
        rotate: int = 0;
        if (`node == None) {
            return None;
        }
        while 1 {
            if (`node.key == key) {
                return `node;
            }
            rotate = not randombits(1);
            if (key < `node.key) {
                next = `node.left;
                if (next == None) {
                    return None;
                }
                if rotate {
                    `node.left = next.right;
                    next.right = `node;
                    pnode = next;
                } else {
                    pnode = `node.left;
                }
            } else {
                next = `node.right;
                if (next == None) {
                    return None;
                }
                if rotate {
                    `node.right = next.left;
                    next.left = `node;
                    pnode = next;
                } else {
                    pnode = `node.right;
                }
            }

            `node = next;
        }
    }
}

def RotatingTree_Enum(
    `root: rotating_node_t, enumfn: rotating_tree_enum_fn, arg: object
) -> int {
    result: int = 0;
    `node: rotating_node_t = rotating_node_t();
    while (`root != None) {
        result = RotatingTree_Enum(`root.left, enumfn, arg);
        if (result != 0) {
            return result;
        }
        `node = `root.right;
        result = enumfn(`root, arg);
        if (result != 0) {
            return result;
        }
        `root = `node;
    }

    return 0;
}
