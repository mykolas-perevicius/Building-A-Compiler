use std::collections::{HashMap, BinaryHeap};
use std::io::{self, BufRead};
use std::cmp::Reverse;

fn main() {
    // Read all lines
    let stdin = io::stdin();
    let lines: Vec<String> = stdin.lock().lines()
        .filter_map(|l| l.ok())
        .collect();

    // Check even
    if lines.len() % 2 != 0 {
        eprintln!("Error: Malformed input (odd number of lines).");
        return;
    }

    // Map from String -> index
    let mut id_map = HashMap::new();
    let mut tasks = Vec::new();

    // function to get or create id
    fn get_id(m: &mut HashMap<String, usize>, v: &mut Vec<String>, s: &str) -> usize {
        if let Some(&idx) = m.get(s) {
            idx
        } else {
            let idx = v.len();
            v.push(s.to_string());
            m.insert(s.to_string(), idx);
            idx
        }
    }

    // Gather all tasks
    for l in &lines {
        get_id(&mut id_map, &mut tasks, l);
    }

    let n = tasks.len();
    let mut graph = vec![Vec::new(); n];
    let mut in_degree = vec![0; n];

    // Build graph (prereq -> task)
    // lines[2*i] depends on lines[2*i+1]
    // edge: (prereq -> task)
    for i in (0..lines.len()).step_by(2) {
        let task_id = get_id(&mut id_map, &mut tasks, &lines[i]);
        let prereq_id = get_id(&mut id_map, &mut tasks, &lines[i+1]);
        graph[prereq_id].push(task_id);
        in_degree[task_id] += 1;
    }

    // We want to pop the lexicographically smallest task => 
    // Rust's BinaryHeap is a max-heap by default, so we store 
    // Reverse(...) plus we compare tasks[..] strings.
    // We'll keep a separate min-structure. 
    // One approach: use a Vec, sort, or use a BTreeSet. 
    // Let's do a BTreeSet for clarity:

    use std::collections::BTreeSet;
    let mut zero_in_degree = BTreeSet::new();

    // Initialize
    for i in 0..n {
        if in_degree[i] == 0 {
            zero_in_degree.insert(i);
        }
    }

    let mut topo_order = Vec::with_capacity(n);

    while !zero_in_degree.is_empty() {
        // pop the smallest by lex ordering of tasks
        // but we only have indices. So we need to find the index 
        // whose tasks[index] is lexicographically smallest.
        // BTreeSet is ordering by the numeric index, not the string. 
        // So we actually need to store something like (tasks[i], i). 
        // We'll do a trick: we'll just scan for the min in BTreeSet 
        // by string. This is O(n) each time. 
        // Alternatively, store tasks in the set as a key. 
        // For demonstration, let's do the naive approach: find the i that is lexicographically smallest. 

        let mut best_idx = None;
        let mut best_str = None;
        for &idx in &zero_in_degree {
            let s = &tasks[idx];
            if best_str.is_none() || s < best_str.as_ref().unwrap() {
                best_str = Some(s);
                best_idx = Some(idx);
            }
        }

        let curr = best_idx.unwrap();
        zero_in_degree.remove(&curr);
        topo_order.push(curr);

        // Decrement in_degree of neighbors
        for &nbr in &graph[curr] {
            in_degree[nbr] -= 1;
            if in_degree[nbr] == 0 {
                zero_in_degree.insert(nbr);
            }
        }
    }

    if topo_order.len() == n {
        for &idx in &topo_order {
            println!("{}", tasks[idx]);
        }
    } else {
        println!("cycle");
    }
}
