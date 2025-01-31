#!/usr/bin/env python3

import sys
import heapq
from collections import defaultdict

def main():
    lines = [line.strip() for line in sys.stdin]
    
    # Check that we have an even number of lines
    if len(lines) % 2 != 0:
        print("Error: Malformed input (odd number of lines).")
        return
    
    in_degree = defaultdict(int)
    graph = defaultdict(set)
    all_tasks = set()
    
    # Build the graph
    for i in range(0, len(lines), 2):
        task = lines[i]
        prereq = lines[i+1]
        
        all_tasks.add(task)
        all_tasks.add(prereq)
        
        # Add edge: prereq -> task
        if task not in graph[prereq]:
            graph[prereq].add(task)
            in_degree[task] += 1
    
    # Initialize min-heap with tasks of in_degree 0
    zero_in_degree = []
    for t in all_tasks:
        if in_degree[t] == 0:
            heapq.heappush(zero_in_degree, t)
    
    topo_order = []
    
    # Topological sort using a heap for lexicographic order
    while zero_in_degree:
        current = heapq.heappop(zero_in_degree)
        topo_order.append(current)
        
        for dependent in graph[current]:
            in_degree[dependent] -= 1
            if in_degree[dependent] == 0:
                heapq.heappush(zero_in_degree, dependent)
    
    # Check for cycle
    if len(topo_order) == len(all_tasks):
        for t in topo_order:
            print(t)
    else:
        print("cycle")

if __name__ == "__main__":
    main()
