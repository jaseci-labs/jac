typedef struct rotating_node_s rotating_node_t;
typedef int (*rotating_tree_enum_fn)(rotating_node_t *node, void *arg);

struct rotating_node_s {
    void *key;
    rotating_node_t *left;
    rotating_node_t *right;
};

static unsigned int random_value = 1;
static unsigned int random_stream = 0;
static int random_mutex = 0;

static void random_lock(void) {
    random_mutex = 1;
}

static void random_unlock(void) {
    random_mutex = 0;
}

static int randombits(int bits) {
    int result;
    random_lock();
    if (random_stream < (1U << bits)) {
        random_value *= 1082527;
        random_stream = random_value;
    }
    result = random_stream & ((1 << bits) - 1);
    random_stream >>= bits;
    random_unlock();
    return result;
}

void RotatingTree_Add(rotating_node_t **root, rotating_node_t *node) {
    while (*root != NULL) {
        if (((char *)(node->key)) < ((char *)((*root)->key)))
            root = &((*root)->left);
        else
            root = &((*root)->right);
    }
    node->left = NULL;
    node->right = NULL;
    *root = node;
}

rotating_node_t *RotatingTree_Get(rotating_node_t **root, void *key) {
    if (randombits(3) != 4) {
        rotating_node_t *node = *root;
        while (node != NULL) {
            if (node->key == key)
                return node;
            if (((char *)(key)) < ((char *)(node->key)))
                node = node->left;
            else
                node = node->right;
        }
        return NULL;
    } else {
        rotating_node_t **pnode = root;
        rotating_node_t *node = *pnode;
        rotating_node_t *next;
        int rotate;
        if (node == NULL)
            return NULL;
        while (1) {
            if (node->key == key)
                return node;
            rotate = !randombits(1);
            if (((char *)(key)) < ((char *)(node->key))) {
                next = node->left;
                if (next == NULL)
                    return NULL;
                if (rotate) {
                    node->left = next->right;
                    next->right = node;
                    *pnode = next;
                } else
                    pnode = &(node->left);
            } else {
                next = node->right;
                if (next == NULL)
                    return NULL;
                if (rotate) {
                    node->right = next->left;
                    next->left = node;
                    *pnode = next;
                } else
                    pnode = &(node->right);
            }
            node = next;
        }
    }
}

int RotatingTree_Enum(
    rotating_node_t *root,
    rotating_tree_enum_fn enumfn,
    void *arg
) {
    int result;
    rotating_node_t *node;
    while (root != NULL) {
        result = RotatingTree_Enum(root->left, enumfn, arg);
        if (result != 0)
            return result;
        node = root->right;
        result = enumfn(root, arg);
        if (result != 0)
            return result;
        root = node;
    }
    return 0;
}
