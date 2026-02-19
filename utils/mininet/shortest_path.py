
# SPDX-FileCopyrightText: 2018 Contributors to the P4 Project
#
# SPDX-License-Identifier: Apache-2.0

class ShortestPath:

    def __init__(self, edges=[]):
        self.neighbors = {}
        for edge in edges:
            self.addEdge(*edge)

    def addEdge(self, a, b):
        self.neighbors.setdefault(a, set()).add(b)
        self.neighbors.setdefault(b, set()).add(a)

    def get(self, a, b, exclude=lambda node: False):
        # Shortest path from a to b
        return self._recPath(a, b, [], exclude)

    def _recPath(self, a, b, visited, exclude):
        if a == b: return [a]
        new_visited = visited + [a]
        paths = []
        for neighbor in self.neighbors[a]:
            if neighbor in new_visited: continue
            if exclude(neighbor) and neighbor != b: continue
            path = self._recPath(neighbor, b, new_visited, exclude)
            if path: paths.append(path)

        paths.sort(key=len)
        return [a] + paths[0] if len(paths) else None

if __name__ == '__main__':

    edges = [
            (1, 2),
            (1, 3),
            (1, 5),
            (2, 4),
            (3, 4),
            (3, 5),
            (3, 6),
            (4, 6),
            (5, 6),
            (7, 8)

    ]
    sp = ShortestPath(edges)

    assert sp.get(1, 1) == [1] # shortest path from node 1 to itself
    assert sp.get(2, 2) == [2] # shortest path from node 2 to itself

    assert sp.get(1, 2) == [1, 2]
    assert sp.get(2, 1) == [2, 1]

    assert sp.get(1, 3) == [1, 3] # shortest path from node 1 to node 3
    assert sp.get(3, 1) == [3, 1] # shortest path from node 3 to node 1

    assert sp.get(4, 6) == [4, 6]
    assert sp.get(6, 4) == [6, 4]

    assert sp.get(2, 6) == [2, 4, 6]
    assert sp.get(6, 2) == [6, 4, 2]

    assert sp.get(1, 6) in [[1, 3, 6], [1, 5, 6]] # Multiple shortest paths from 1 to 6
    assert sp.get(6, 1) in [[6, 3, 1], [6, 5, 1]] # Multiple shortest paths from 6 to 1

    assert sp.get(2, 5) == [2, 1, 5]
    assert sp.get(5, 2) == [5, 1, 2]

    assert sp.get(4, 5) in [[4, 3, 5], [4, 6, 5]]
    assert sp.get(5, 4) in [[5, 3, 4], [6, 6, 4]]

    assert sp.get(7, 8) == [7, 8]
    assert sp.get(8, 7) == [8, 7]

    assert sp.get(1, 7) == None # There is no path from node 1 to node 7
    assert sp.get(7, 2) == None # There is no path from node 7 to node 2

