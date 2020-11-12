---
title: Algorithms - Graphs
date: 2020-05-01 09:00:00
tags:
    - Algorithms
category: notes
keywords:
    - Algorithms
    - Graphs
mathjax: true
---

## Undirected Graphs

### Some problems

* Path
* Shortest path
* Cycle
* Ehler tour: A cycle that uses each edge excatly once.
* Hamilton tour: A cycle that uses each vertex exactly once
    - classical NP-complete problem.
* Connectivity
* MST:
* Biconnectivity: A vertex whose removal disconnects the graph
* Planarity
* Graph isomorphism: Are two graphs identical?
    - No one knows so far. A lonstanding open problem

### Representations

Real-world graphs tend to be **sparse** (huge number of vertices, small average vertex degree).

* Set-of-edges representation
    - unefficient
* Adjacency-matrix representation
    - space cost is prohibitive
* Adjacency-list array representation
    - GOOD

### Adjacency-list Data structure

* Space usage proportional to V + E
* Constant time to add an edge
* Time proportional to the degree of v to iterate through vertices adjacent to v

### Depth-first Search (DFS)

Typical applications:
* Find all vertices connected to a given source vertex
* Find a path between two vertices

Algorithm:
* Use recursion (a function-call stack) or an explicit stack.
* Mark each visited vertex (and keep track of edge taken to visit it)
* Return (retrace steps) when no unvisited options

```Java
public class DepthFirstPaths{
    private blloean[] marked;
    private int[] edgeTO;
    private int s;
    public DepthFirstPaths(Graph G, int s)
    {
        // ...
        dfs(G, s);
    }

    private void dfs(Graph Gm int v)
    {
        marked[v] = true;
        for (int w : G.adj(v))
            if (!marked[v])
            {
                dfs(G, w)
                edgeTo[w] = v;
            }
    }
}
```

Propositions:
1. DFS marks all vertices connected to s in time proportional to the sum of their degrees.
2. After DFS, can find vertices connected to s in constant time and can find a path to s in time proportional to its length.

### Breadth-first Search (BFS)

Typical applications:
* shortest path

Algorithm:
* Put s onto a queue, and mark s as visited
* Take the next vertex v from the queue and mark it
* Put onto the queue all unmarked vertices that are adjacent to v

```Java
public class BreadthFirstPaths
{
    private boolean[] marked;
    private int[] edgeTo;
    // ...
    private void bfs(Graph G, int s)
    {
        Queue<Integer> q = new Queue<>();
        q.enqueue(s);
        marked[s] = ture;
        while (!q.isEmpty())
        {
            int v = q.dequeue();
            for (int w: G.adj(v))
            {
                if (!marked[w])
                {
                    q.enqueue(w);
                    marked[w] = true;
                    edgeTo[w] = v;
                }
            }
        }
    }
}
```

Proposition:
1. BFS computes shortest paths (fewest number of edges) from s to all other vertices in a graph in time proportional to E + V

### Applications of DFS

#### Connected components

The goal is to preprocess graph to answer queries of the form *is v connected to w?* in constant time.

The relation *is connected to* is an equivalence relation:
* Reflexive: v is connected to v
* Symmetric: if v is connected to w, then w is connected to v
* Transitive: if v connected to w and w connected to x, then v connected to x

```Java
public class CC {
    private boolean[] marked;
    private int[] id;
    private int count;

    public CC(Graph G) {
        marked = new boolean[G.V()];
        id = new int[G.V()];
        for (int v = 0, v < G.V(); v++) {
            if (!marked[v]) {
                dfs(G, v);
                count++;
            }
        }
    }

    // ...

    private void dfs(Graph G, int v) {
        marked[v] = true;
        id[v] = count;
        for (int w : G.adj(v)) {
            if (!marked[w]) {
                dfs(G, w)
            }
        }
    }
}
```

#### Cycle detection

Problem: Is a given graph acylic?

**TODO**

#### Two-colorability

Problem: Is the graph bipartite?

**TODO**

#### Symbol graphs

**TODO**

#### Degrees of separation

**TODO**

## Directed Graphs

>A directed graph (or digraph) is a set of vertices and a collection of directed edges. Each directed edge connects an ordered pair of vertices.

* *outdegree*: the number of edges going **from** it
* *indegree*: the number fo edges going **into** it
* *directed path*: a sequence of vertices in which there is a (directed) edge pointing from each vertex in the sequence to its successor in the sequence
* *directed cycle*
* *simple cycle*: a cycle with no repeated edges or vertices


### Representations

Again, use [adjacency-lists representation](#Adjacency-list-Data-structure)
* Based on iterating over vertices pointing from v
* Real-world digraphs tend to be sparse

```Java
public class Digraph {
    private final int V;
    private final Bag<Integer>[] adj;

    public Digraph(int V) {
        this.V = V;
        adj = (Bag<Integer>[]) new Bag[V];
        for (int v = 0; v < V; v++) {
            adj[v] = new Bag<Integer>[];
        }
    }

    public void addEdge(int v, int w) {
        adj[v].add(w);
    }

    public Iterable<Integer> adj(int v) {
        return adj[v];
    }
}
```

### Digraph search

Reachabiliity problem: Find all vertices reachable from s along a directed path.

We can use [the same dfs method as for undirected graphs](#Depth-first-Search-(DFS)).
* Every undirected graph is a digraph with edges in both directions.
* DFS is a digraph algorithm,

Reachability applications:
* program control-flow analysis
    - Dead-code elimination
    - infinite-loop detection
* mark-sweep garbage collector


Other DFS problems:
* Path findind
* Topological sort
* Directed cycle detection
* ...

BFS problems:
* shortest path
* multiple-source shortest paths
* web crawler application

### Topological Sort

>Topological sort: Given a digraph, put the vertices in order such that all its directed edges point from a vertix earlier in the order to a vertex later in the order (or report impossible).

A digraph has a topological order **if and only if** it is a *directed acyclic graph* (DAG).
Topological sort redraws DAG so all edges poitn upwards.

use **DFS** again. It can be proved that reverse postorder of a DAG is a topological order.
(check P578 for the definition of Preorder/Postorder)

```Java
public class DepthFirstOrder {
    private boolean[] marked;
    private Stack<Integer> reversePost;

    publiv DepthFirstOrder(Digraph G) {
        reversePost = new Stack<Integer>();
        marked = new boolean[G.V()];
        for (int v = 0; v < G.V(); v++) {
            if (!marked[v]) dfs(G, v);
        }
    }

    private void dfs(Digrapg G, int v) {
        marked[v] = true;
        for (int w : G.adj(v)) {
            if (!marked[w]) dfs(G, w)
        }
        reversePost.push(v);
    }
}
```

#### Directed cycle detection

To find out if a given digraph is a DAG, we can try to find a directec cycle in the digraph.
Use DFS and a stack to track the cycle.

```Java
// TODO
```

Some very typical applications of directed cycle detection and topological sort:
(A directed cycle means the problem is infeasible)
* job schedule
* course scuedule
* inheritance
* spreadsheet
    - vertex: cell
    - edge: formula
* symbolic links

### Strong components

Vertices v and w are **strongly connected** if there is both a directed path from v to w and a directed path from w to v.
Strong connectivity is an equvicalence relation.

#### Kosaraju-Sharir Algorithm

Kosaraju-Sharir is easy to implement but difficutl to understand. It runs DFS twice:
* Given a digraph G, run DFS to compute the topological order of its reverse $G^R$
* Run DFS on G in the order given by first DFS

TODO: ADD Proof

[https://algs4.cs.princeton.edu/code/edu/princeton/cs/algs4/KosarajuSharirSCC.java.html](https://algs4.cs.princeton.edu/code/edu/princeton/cs/algs4/KosarajuSharirSCC.java.html)
```Java
public class KosarajuSharirSCC {
    private boolean[] marked;     // marked[v] = has vertex v been visited?
    private int[] id;             // id[v] = id of strong component containing v
    private int count;            // number of strongly-connected components

    /**
     * Computes the strong components of the digraph {@code G}.
     * @param G the digraph
     */
    public KosarajuSharirSCC(Digraph G) {

        // compute reverse postorder of reverse graph
        DepthFirstOrder dfs = new DepthFirstOrder(G.reverse());

        // run DFS on G, using reverse postorder to guide calculation
        marked = new boolean[G.V()];
        id = new int[G.V()];
        for (int v : dfs.reversePost()) {
            if (!marked[v]) {
                dfs(G, v);
                count++;
            }
        }
    }

    // DFS on graph G
    private void dfs(Digraph G, int v) { 
        marked[v] = true;
        id[v] = count;
        for (int w : G.adj(v)) {
            if (!marked[w]) dfs(G, w);
        }
    }

    // ...
}
```


## Minimum Spanning Trees

An edge-weighted-graph is a graph where we associate weight or costs with each edge.
A spanning tree of an undirected edge-weighted graph G is a subgraph T that is both **a tree (conneted and acyclic)** and **spanning (includes all of the vertices)**.
Given an (connected) undirected edge-weighted graph G with V vertices and E edges, the MST of it must have **V - 1** edges.
If the graph is not connceted, we compute minimum spanning forest (MST of each component).

* A *cut* in a graph is a partition of its vertices into two (nonempty) sets
* A *crossing edge* connects a vertex in one set with a vertex in the other.
* Cut property: Given any cut, the crossing edge of min weight is in the MST.

### Edge-weight Graph Data Type

Edge:
[https://algs4.cs.princeton.edu/code/edu/princeton/cs/algs4/Edge.java.html](https://algs4.cs.princeton.edu/code/edu/princeton/cs/algs4/Edge.java.html)

EdgeWeigthedGraph:
[https://algs4.cs.princeton.edu/code/edu/princeton/cs/algs4/EdgeWeightedGraph.java.html](https://algs4.cs.princeton.edu/code/edu/princeton/cs/algs4/EdgeWeightedGraph.java.html)

### **Greedy MST Algorithm:**
* Start with all edges colored gray.
* Find cut with no blacked crossing edges; color its min-weight edge black.
* Repeat until V-1 edges are colored black.

### Implementations 1: Kruskal's algorithm

For edges in ascending order of weight:
* Add next edge to Tree unless doing so would create a cycle.

To efficiently solve this problem, use union-find :
1. use a priority queue to maintain all the edges in V
2. union-find data structure:
    - maintain a set for each connected component in T.
    - if v and w are in saome set, then adding v->w would create a cycle
    - to add v>w to T, merge sets containing v and w.

TODO: Add code

### Implementations 2: Prim's algorithm

* Start with vertex 0 and greedily grow tree T.
* Add To T the min weight edge with exactly oue endpoint in T.
* Reapeat unitl V - 1 edges.

The key to solve this problem is how do we find the crossing edge of minimal weight efficiently.

A lazy solution (in time proportional to $ElogE$, fair enough):
1. Maintain a PQ of edges with (at least) one endpoint in T
    - Key = edge, priority = weight
2. Delete-min to determine next edge e = v->w to add to T
3. Disregard if both endpoints v and w are marked (both in T)
4. Otherwise, let w be the unmarked vertex (not in T)
    - add to PQ and edge incident to w (assuming other endpoint not in T)
    - add e to T and mark w

TODO: add code

A eager solution (in time proprotional to $ElogV$, better):
1. Maintain a PQ of vertices connected by an edge to T, where priority of v = weight of shortedt edge connecting v to T
2. Delete min vertex v and add its associated edge e = v->w to T
3. Update PQ by considering all edges e = v->x incident to v
    - ignore if x is already in T
    - add x to PQ if not alread on it
    - decrease priority of x if v->x becomes shortest edge connecting x to T

This solution uses an [indexed priority queue](https://algs4.cs.princeton.edu/code/edu/princeton/cs/algs4/IndexMinPQ.java.html) data structure.

TODO: add code

## Shortest Paths

**Some variants:**
* Which vertices?
    - Single source
    - Source-sink
    - All pairs
* Edge weights
    - Nonegative weights
    - Euclidean weights
    - Arbitrary weights
* Cycles?
    - No directed cycles
    - No negative cycles

### Edge-weighted digraph data strcuture

Weighted directed edge:
[https://algs4.cs.princeton.edu/code/edu/princeton/cs/algs4/DirectedEdge.java.html](https://algs4.cs.princeton.edu/code/edu/princeton/cs/algs4/DirectedEdge.java.html)

Edge-weighted digraph:
[https://algs4.cs.princeton.edu/code/edu/princeton/cs/algs4/EdgeWeightedDigraph.java.html](https://algs4.cs.princeton.edu/code/edu/princeton/cs/algs4/EdgeWeightedDigraph.java.html)

Use adjacency-lists implementation same as [EdgeWeightedGraph](https://algs4.cs.princeton.edu/code/edu/princeton/cs/algs4/EdgeWeightedGraph.java.html)

### Generic Single-source Shortest paths

Our goal is to find the shortest path from s to every other vertex. As a result, what we find will be the **shortest-paths tree (SPT)** for source s.

#### Relax edge e = v->w

* distTo[v] is length of shortest known path from s to v
* distTo[w] is length of shortest known path from s to w
* esgeTo[w] is last edge on shortest known pathh from s to w
* if e = v->w gives shorter path to w through v, update both distTo[w] and edgeTo[w]

```Java
private void relax(DirectedEdge e) {
    int v = e.from(), w = e.to();
    if (distTo[w] > distTo[v] + e.weight()) {
        distTo[w] = distTo[v] + e.weight();
        edgeTo[w] = e;
    }
}
```

#### Optimality conditions

Given an edge-weighted digraph G, distTo[] are the shortest path distances from s **iff**:
* distTo[s] = 0
* For each vertex v, distTo[v] is the length of some path from s to v.
* For each edge e = v->w, distTo[w] <= distTo[v] + e.weight()

#### Generic algorithm

```
Generic algorithm (to compute SPT from s) {
    Initialize distTo[s] = 0 and distTo[v] = $\infty$

    Repeat until optimality conditions are satisfied:
        - Relax any edge
}
```

Efficient implementations:
* Nonnegative weights: [Dijkstra's algorithm](#implement-1-dijkstras-algorithm)
* No directed cycles (DAGs): [Topological sort algorithm](#implement-2-topological-sort-algorithm)
* No negative cycles: [Bellman-Ford](#implement-3-bellman-ford-algorithm)

### Implement 1: Dijkstra's algorithm
When there is no nonnegative weight exists, we can use Dijkstra's algorithm.
* Consider vertices in increasing order of distance from s (non-tree vertex with the lowest distTo[] value)
* add vertex to tree and relax all edges pointing from that vertex

```Java
public class DijkstraSP{
        // ...
    public DijkstraSP(EdgeWeightedDigraph G, int s) {
        edgeTo = new DirectedEdge[G.V()];
        distTo = new double[G.V()];
        pq = new IndexMinPQ<Double>(G.V());

        for (int v = 0; v < G.V(); v++) {
            distTo[v] = Double.POSITIVE_INFINITY;
        }
        distTo[s] = 0;

        pq.insert(s, 0.0);
        while(!pq.isEmpty()) {
            int v= pq.delMin();
            for (DirectedEdge e : G.adj(v)) {
                relax(e);
            }
        }
    }

    private void relax(DirectedEdge e) {
        int v = e.from(), w = e.to();
        if (distTo[w] > distTo[v] + e.weight()) {
            distTo[w] = distTo[v] + e.weight();
            edgeTo[w] = e;
            if (pq.contains(w)) pq.decreaseKey(w, distTo[w]);
            else pq.insert(w, distTo[w]);
        }
    }
}
```

**Compare to Prim's algorithm:**
* Both are computing a graph's spanning tree
* Prim's algorithm choose closest vertex to tree as next vertex, while Dijkstra's algorithm choose closest vertex to the source

### Implement 2: Topological sort algorithm

When the graph is a DAG, we can consider vertices in topological order and do relaxing.

```Java
    // ...
    Topological topological = new Topological(G);
    for (int v : topological.order()) {
        for (DirectedEdge e : G.adj(v)) {
            relax(e);
        }
    }
```

**[Seam carving](https://en.wikipedia.org/wiki/Seam_carving)**: Resize an image without distortion.

**Longest paths**:
* Formuate as a shortest paths problem in edge-weighted DAGs
    - Negate all weights
    - Find shortest paths
    - Negate weights in result
* Allpication: Parallel job scheduling ([Critical path method, CPM](https://ja.wikipedia.org/wiki/%E3%82%AF%E3%83%AA%E3%83%86%E3%82%A3%E3%82%AB%E3%83%AB%E3%83%91%E3%82%B9%E6%B3%95)).

### Implement 3: Bellman-Ford algorithm

>A SPT exists iff no negative cycles (a directed cycle whose sum of edge weights is negative).

When we want to find shortest paths with nagative weights, Dijkstra's algorithms doesn't work.
We can use Bellman-Ford algorithm as long as there is no negative cycle in the graph.
(Bellman-Ford algorithm is a dynamic programming algorithm)

* Initialize distTo[s] = 0 and distTo[v] = $\infty$
* Maintain a queue and repeat until the queue is empty or find a cycle:
    - Pop vertex v from q
    - Relax each edge pointing from v to  any vertex w:
        - if distTo[w] can be de decreased, update distTo[w] and add w to the queue

```Java
// ...
    public BellmanFordSP(EdgeWeightedDigraph G, int s) {
        distTo  = new double[G.V()];
        edgeTo  = new DirectedEdge[G.V()];
        onQueue = new boolean[G.V()];
        for (int v = 0; v < G.V(); v++)
            distTo[v] = Double.POSITIVE_INFINITY;
        distTo[s] = 0.0;

        // Bellman-Ford algorithm
        queue = new Queue<Integer>();
        queue.enqueue(s);
        onQueue[s] = true;
        while (!queue.isEmpty() && !hasNegativeCycle()) {
            int v = queue.dequeue();
            onQueue[v] = false;
            relax(G, v);
        }
    }

    private void relax(EdgeWeightedDigraph G, int v) {
        for (DirectedEdge e : G.adj(v)) {
            int w = e.to();
            if (distTo[w] > distTo[v] + e.weight()) {
                distTo[w] = distTo[v] + e.weight();
                edgeTo[w] = e;
                if (!onQueue[w]) {
                    queue.enqueue(w);
                    onQueue[w] = true;
                }
            }
            if (++cost % G.V() == 0) {
                findNegativeCycle();
                if (hasNegativeCycle()) return;  // found a negative cycle
            }
        }
    }

```

Bellman-Ford algorithm can also be used for finding a negative cycle.

Negative cycle application: arbitrage detection.
