#include <bits/stdc++.h>
using namespace std;

int main() {
    ios::sync_with_stdio(false);
    cin.tie(nullptr);

    // Read all lines from stdin into a vector
    vector<string> lines;
    {
        string s;
        while (true) {
            if (!std::getline(cin, s)) break;
            if(!s.empty() && s.back() == '\r') {
                s.pop_back(); // handle CR if present
            }
            lines.push_back(s);
        }
    }

    // Check if even number of lines
    if (lines.size() % 2 != 0) {
        cerr << "Error: Malformed input (odd number of lines).\n";
        return 1;
    }

    // Map from string task -> int id
    unordered_map<string,int> id_map;
    vector<string> tasks; // to hold the reverse mapping id->task
    tasks.reserve(lines.size() * 2);

    // function to get or create id
    function<int(const string&)> get_id = [&](const string &t){
        auto it = id_map.find(t);
        if (it != id_map.end()) {
            return it->second;
        }
        int new_id = (int)tasks.size();
        tasks.push_back(t);
        id_map[t] = new_id;
        return new_id;
    };

    // First pass: gather all tasks
    for (auto &l : lines) {
        get_id(l);
    }

    int n = (int)tasks.size();
    vector<vector<int>> graph(n);
    vector<int> in_degree(n,0);

    // Build the graph from pairs (task depends on prereq) => edge: prereq -> task
    for (int i = 0; i < (int)lines.size(); i += 2) {
        int task_id = get_id(lines[i]);
        int prereq_id = get_id(lines[i+1]);
        // add edge prereq_id -> task_id if not already added
        // (for simplicity, ignore duplicates or check)
        graph[prereq_id].push_back(task_id);
        in_degree[task_id]++;
    }

    // Use a min-heap (priority queue) for tasks with 0 in-degree
    // but we need the smallest string first => use a custom compare that uses tasks[id]
    // We'll store the IDs, but compare their corresponding strings
    auto cmp = [&](int a, int b){ return tasks[a] > tasks[b]; };
    priority_queue<int,vector<int>,decltype(cmp)> pq(cmp);

    // Push all tasks with in_degree=0
    for (int i = 0; i < n; i++) {
        if (in_degree[i] == 0) {
            pq.push(i);
        }
    }

    vector<int> topo_order;
    topo_order.reserve(n);

    while (!pq.empty()) {
        int curr = pq.top();
        pq.pop();
        topo_order.push_back(curr);
        // Decrease in_degree of neighbors
        for (auto &nbr : graph[curr]) {
            in_degree[nbr]--;
            if (in_degree[nbr] == 0) {
                pq.push(nbr);
            }
        }
    }

    if ((int)topo_order.size() == n) {
        // Print tasks in topological order
        for (auto &id : topo_order) {
            cout << tasks[id] << "\n";
        }
    } else {
        cout << "cycle\n";
    }

    return 0;
}
