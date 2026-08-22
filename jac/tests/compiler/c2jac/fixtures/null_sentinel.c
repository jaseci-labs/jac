typedef struct node_s node_t;

struct node_s {
    node_t *left;
    node_t *right;
};

node_t *find(node_t *root) {
    if (root == NULL)
        return NULL;
    while (root != NULL) {
        if (root->left == NULL)
            return NULL;
        root = root->left;
    }
    root->left = NULL;
    return root;
}
