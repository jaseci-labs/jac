class TestGenericAliasCore(unittest.TestCase):
    def test_list_type(self):
        self.assertIs(type([1, 2]), list)

    def test_dict_type(self):
        self.assertIs(type({'a': 1}), dict)
