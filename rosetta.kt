import java.util.*
import kotlin.collections.ArrayList

fun main() {
    val lines = generateSequence(::readLine).toList()
    
    // Check even number of lines
    if (lines.size % 2 != 0) {
        System.err.println("Error: Malformed input (odd number of lines).")
        return
    }

    // Map from task string -> int ID
    val idMap = HashMap<String, Int>()
    val tasks = ArrayList<String>()

    // assign IDs
    for (s in lines) {
        if (!idMap.containsKey(s)) {
            idMap[s] = tasks.size
            tasks.add(s)
        }
    }

    val n = tasks.size
    val graph = Array(n) { ArrayList<Int>() }
    val inDegree = IntArray(n) { 0 }

    // Build graph (prereq -> task)
    for (i in lines.indices step 2) {
        val task = lines[i]
        val prereq = lines[i+1]
        val tId = idMap[task]!!
        val pId = idMap[prereq]!!
        graph[pId].add(tId)
        inDegree[tId]++
    }

    // Use a priority queue for zero in-degree tasks, sorted lexicographically by tasks[id]
    val pq = PriorityQueue<Int>(compareBy { tasks[it] })
    for (i in 0 until n) {
        if (inDegree[i] == 0) {
            pq.add(i)
        }
    }

    val topoOrder = ArrayList<Int>(n)

    while (pq.isNotEmpty()) {
        val curr = pq.poll()
        topoOrder.add(curr)
        for (neighbor in graph[curr]) {
            inDegree[neighbor]--
            if (inDegree[neighbor] == 0) {
                pq.add(neighbor)
            }
        }
    }

    if (topoOrder.size == n) {
        for (id in topoOrder) {
            println(tasks[id])
        }
    } else {
        println("cycle")
    }
}
