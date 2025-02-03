file:///C:/Users/miciu/Desktop/Compilers%20(485)/Rosetta.java
### java.util.NoSuchElementException: next on empty iterator

occurred in the presentation compiler.

presentation compiler configuration:


action parameters:
offset: 1291
uri: file:///C:/Users/miciu/Desktop/Compilers%20(485)/Rosetta.java
text:
```scala
import java.util.*;
import java.io.*;

public class Rosetta {
    public static void main(String[] args) throws IOException {
        // Read all lines from stdin
        ArrayList<String> lines = new ArrayList<>();
        BufferedReader br = new BufferedReader(new InputStreamReader(System.in));
        String line;
        while ((line = br.readLine()) != null) {
            line = line.replace("\r", ""); // strip CR if needed
            lines.add(line);
        }
        br.close();

        // Check if even number of lines
        if (lines.size() % 2 != 0) {
            System.err.println("Error: Malformed input (odd number of lines).");
            return;
        }

        // Map from task string -> integer ID
        HashMap<String,Integer> idMap = new HashMap<>();
        ArrayList<String> tasks = new ArrayList<>(); // for reverse lookup

        // Helper to get or create ID
        // returns the existing ID if the task is known, otherwise creates a new entry
        int nextId = 0;
        for (String s : lines) {
            if (!idMap.containsKey(s)) {
                idMap.put(s, nextId);
                tasks.add(s);
                nextId++;
            }
        }

        int n = tasks.size();
        List<List<In@@teger>> graph = new ArrayList<>(n);
        for (int i = 0; i < n; i++) {
            graph.add(new ArrayList<>());
        }
        int[] inDegree = new int[n];

        // Build graph from pairs: lines[2*i] depends on lines[2*i+1]
        // Edge: prereq -> task
        for (int i = 0; i < lines.size(); i += 2) {
            String task = lines.get(i);
            String prereq = lines.get(i+1);
            int tId = idMap.get(task);
            int pId = idMap.get(prereq);
            graph.get(pId).add(tId);
            inDegree[tId]++;
        }

        // PriorityQueue for tasks with in_degree=0, sorted by their string name
        PriorityQueue<Integer> pq = new PriorityQueue<>(new Comparator<Integer>() {
            @Override
            public int compare(Integer a, Integer b) {
                // compare tasks[a] and tasks[b] lexicographically
                return tasks.get(a).compareTo(tasks.get(b));
            }
        });

        // Add initial zero in-degree tasks
        for (int i = 0; i < n; i++) {
            if (inDegree[i] == 0) {
                pq.offer(i);
            }
        }

        ArrayList<Integer> topoOrder = new ArrayList<>(n);

        while (!pq.isEmpty()) {
            int curr = pq.poll();
            topoOrder.add(curr);

            // Decrement in-degree of neighbors
            for (int neighbor : graph.get(curr)) {
                inDegree[neighbor]--;
                if (inDegree[neighbor] == 0) {
                    pq.offer(neighbor);
                }
            }
        }

        if (topoOrder.size() == n) {
            for (int id : topoOrder) {
                System.out.println(tasks.get(id));
            }
        } else {
            System.out.println("cycle");
        }
    }
}

```



#### Error stacktrace:

```
scala.collection.Iterator$$anon$19.next(Iterator.scala:973)
	scala.collection.Iterator$$anon$19.next(Iterator.scala:971)
	scala.collection.mutable.MutationTracker$CheckedIterator.next(MutationTracker.scala:76)
	scala.collection.IterableOps.head(Iterable.scala:222)
	scala.collection.IterableOps.head$(Iterable.scala:222)
	scala.collection.AbstractIterable.head(Iterable.scala:935)
	dotty.tools.dotc.interactive.InteractiveDriver.run(InteractiveDriver.scala:164)
	dotty.tools.pc.MetalsDriver.run(MetalsDriver.scala:45)
	dotty.tools.pc.HoverProvider$.hover(HoverProvider.scala:40)
	dotty.tools.pc.ScalaPresentationCompiler.hover$$anonfun$1(ScalaPresentationCompiler.scala:376)
```
#### Short summary: 

java.util.NoSuchElementException: next on empty iterator