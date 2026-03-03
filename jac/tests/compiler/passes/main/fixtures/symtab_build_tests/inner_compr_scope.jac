# Test InnerCompr scope linking - variables from outer scope should be accessible
glob pool = [1, 2, 3],
     any_result = any(isinstance(p, int) for p in pool),
     matrix = [[1, 2], [3, 4]],
     flat = [val for row in matrix for val in row];
