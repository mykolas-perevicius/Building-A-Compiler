#!/usr/bin/env python3

import sys
from collections import defaultdict, deque

def main():
    # Read all lines from stdin and strip them
    lines = [line.strip('\r\n') for line in sys.stdin.readlines()]
    
    # We expect an even number of lines (pairs of tasks)
    if len(lines) % 2 != 0:
        # If there's an odd number of lines, input is malformed based on the spec
        # Behavior for malformed input is unspecified, but we'll just exit.
        return
    
    # Each pair: lines[2*i], lines[2*i+1]
    # line[2*i] depends on line[2*i+1].
    # So if we say "task -> set of tasks it depends on"
    # we must store that line[2*i+1] is a prerequisite for line[2*i].
    
    # We'll keep track of:
    # 1) in_degree[task]: number of prerequisites for each task
    # 2) graph[task]: list/set of tasks that depend on "task"
    # 3) all_tasks: set of all distinct tasks
    in_degree = defaultdict(int)
    graph = defaultdict(set)  # adjacency list (edge from dep -> dependent)
    all_tasks = set()
    
    # Build the graph
    for i in range(0, len(lines), 2):
        task = lines[i]
        prereq = lines[i+1]
        
        # Record tasks
        all_tasks.add(task)
        all_tasks.add(prereq)
        
        # If not already recorded, in_degree entries default to 0
        # Add the edge: prereq -> task
        if task not in graph[prereq]:
            graph[prereq].add(task)
            in_degree[task] += 1
    
    # Now we do a topological sort with ASCII-based tie-breaking for tasks with in_degree = 0
    # Start with all tasks that have in_degree 0
    zero_in_degree = []
    for t in all_tasks:
        if in_degree[t] == 0:
            zero_in_degree.append(t)
    
    zero_in_degree.sort()
    
    topo_order = []
    
    while zero_in_degree:
        current = zero_in_degree.pop(0)  # pop from the front
        topo_order.append(current)
        
        # For each task that depends on current
        for dependent_task in graph[current]:
            in_degree[dependent_task] -= 1
            if in_degree[dependent_task] == 0:
                # Insert in alphabetical order to maintain sorted property
                # A typical approach might be to just append and sort,
                # but we'll do a simple insertion here for clarity
                # (or we can just append and sort again after).
                zero_in_degree.append(dependent_task)
        zero_in_degree.sort()
    
    # If we used all tasks, topo_order should contain all of them
    if len(topo_order) == len(all_tasks):
        for t in topo_order:
            print(t)
    else:
        # There must be a cycle
        print("cycle")

if __name__ == "__main__":
    main()
