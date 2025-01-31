#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

/*
  A simple approach in C:
  1) Read all lines into a dynamic array lines[].
  2) If number_of_lines is odd -> print error and exit.
  3) We'll store tasks in a dynamic array unique_tasks[], 
     and use a function get_task_id() that returns the index 
     in that array. We'll keep them sorted so we can do a 
     binary search. This ensures we can also do lex ordering 
     easily if needed.
  4) Build adjacency list: adj[u] = list of v for "u -> v".
  5) Keep in_degree[v].
  6) Repeatedly find the lex smallest task with in_degree=0 
     that is not yet in the topo order, append it to the result, 
     and decrement in_degree of its neighbors.
  7) If we processed all tasks, print them. Otherwise print "cycle".
*/

#define INITIAL_LINES_CAP 1000
#define INITIAL_TASKS_CAP 1000

// We'll store up to some maximum length for each line/task
#define MAX_LINE_LEN 200

// A structure to hold adjacency info
typedef struct {
    int *neighbors; 
    int capacity;
    int size;
} AdjList;

// We expand adjacency list capacity if needed
void adjlist_init(AdjList *adj) {
    adj->capacity = 4;
    adj->size = 0;
    adj->neighbors = (int*)malloc(sizeof(int)*adj->capacity);
}

void adjlist_add(AdjList *adj, int v) {
    if (adj->size >= adj->capacity) {
        adj->capacity *= 2;
        adj->neighbors = (int*)realloc(adj->neighbors, sizeof(int)*adj->capacity);
    }
    adj->neighbors[adj->size++] = v;
}

// We'll store all lines read
static char **lines = NULL;
static int line_count = 0;
static int lines_cap = 0;

// We'll store unique tasks in a sorted array unique_tasks[]
static char **unique_tasks = NULL;
static int tasks_count = 0;
static int tasks_cap = 0;

// We'll store adjacency in an array of AdjList
static AdjList *adj = NULL;
static int *in_degree = NULL;

/* 
   We keep tasks in a sorted array. We use binary search 
   to find their indices. If not found, we insert 
   in the correct place to keep it sorted.
*/
int task_cmp(const void *a, const void *b) {
    return strcmp(*(const char**)a, *(const char**)b);
}

// Binary search for task in unique_tasks[]
// If found, return index; if not, return -1
int binary_search_tasks(char *task) {
    int left = 0, right = tasks_count - 1;
    while (left <= right) {
        int mid = (left + right) / 2;
        int cmp = strcmp(task, unique_tasks[mid]);
        if (cmp == 0) return mid;
        else if (cmp < 0) right = mid - 1;
        else left = mid + 1;
    }
    return -1;
}

// Insert a new task into unique_tasks[] in sorted position
int insert_task(char *task) {
    // If we have capacity issues, expand
    if (tasks_count >= tasks_cap) {
        tasks_cap *= 2;
        unique_tasks = (char**)realloc(unique_tasks, sizeof(char*) * tasks_cap);
    }

    // Insert in alphabetical order
    // We'll do a linear search from the end, but we could also do a binary search
    // for the insertion point. Since tasks_count might be large,
    // let's do binary search for the insertion index.
    int left = 0, right = tasks_count - 1, pos = tasks_count;
    while (left <= right) {
        int mid = (left + right)/2;
        int cmp = strcmp(task, unique_tasks[mid]);
        if (cmp < 0) {
            pos = mid;
            right = mid - 1;
        } else {
            left = mid + 1;
        }
    }

    // Move elements to make space
    for (int i = tasks_count; i > pos; i--) {
        unique_tasks[i] = unique_tasks[i-1];
    }

    unique_tasks[pos] = task; 
    tasks_count++;
    return pos;
}

// Return index of task in unique_tasks[], inserting if necessary
int get_task_id(const char *src) {
    // We must store a copy of src
    char *task = strdup(src);
    // Check if it exists
    int idx = binary_search_tasks(task);
    if (idx >= 0) {
        // Already present
        free(task); // free the new copy since we don't need it
        return idx;
    }
    // Not found, so insert
    return insert_task(task);
}

int main(void) {
    // 1) Read lines until EOF
    lines_cap = INITIAL_LINES_CAP;
    lines = (char**)malloc(sizeof(char*) * lines_cap);

    char buffer[MAX_LINE_LEN];
    while (1) {
        if (!fgets(buffer, MAX_LINE_LEN, stdin)) {
            break; // EOF
        }
        // strip newline
        char *nl = strchr(buffer, '\n');
        if (nl) *nl = '\0';

        // store
        if (line_count >= lines_cap) {
            lines_cap *= 2;
            lines = (char**)realloc(lines, sizeof(char*) * lines_cap);
        }
        lines[line_count++] = strdup(buffer);
    }

    // 2) Check if even number of lines
    if (line_count % 2 != 0) {
        fprintf(stderr, "Error: Malformed input (odd number of lines).\n");
        // cleanup
        for (int i = 0; i < line_count; i++) {
            free(lines[i]);
        }
        free(lines);
        return 1;
    }

    // 3) Build tasks list
    tasks_cap = INITIAL_TASKS_CAP;
    unique_tasks = (char**)malloc(sizeof(char*) * tasks_cap);
    tasks_count = 0;

    // We'll store edges in a second pass
    // But first let's just gather tasks
    for (int i = 0; i < line_count; i++) {
        get_task_id(lines[i]); // this ensures the task is in unique_tasks
    }

    // Now we have tasks_count unique tasks
    // Build adjacency lists and in_degree
    adj = (AdjList*)malloc(sizeof(AdjList) * tasks_count);
    in_degree = (int*)malloc(sizeof(int) * tasks_count);

    for (int i = 0; i < tasks_count; i++) {
        adjlist_init(&adj[i]);
        in_degree[i] = 0;
    }

    // For each pair of lines: lines[2i] depends on lines[2i+1]
    // -> so edge (prereq -> task)
    for (int i = 0; i < line_count; i += 2) {
        int task_id = get_task_id(lines[i]);
        int prereq_id = get_task_id(lines[i+1]);
        // add edge: prereq_id -> task_id
        // but ensure we don't add duplicates repeatedly:
        // we'll do a simple check by scanning adjacency quickly
        AdjList *al = &adj[prereq_id];
        int already_added = 0;
        for (int k = 0; k < al->size; k++) {
            if (al->neighbors[k] == task_id) {
                already_added = 1;
                break;
            }
        }
        if (!already_added) {
            adjlist_add(al, task_id);
            in_degree[task_id]++;
        }
    }

    // 4) We'll do a topological sort. 
    // We'll repeatedly pick the lex smallest task with in_degree=0 that isn't used yet
    int used_count = 0;
    int *used = (int*)calloc(tasks_count, sizeof(int)); // track if a task is already in topo order

    // We'll store the result in topological[]
    int *topological = (int*)malloc(sizeof(int)*tasks_count);
    int topo_idx = 0;

    while (used_count < tasks_count) {
        // find the lexicographically smallest task with in_degree=0 and not used
        int candidate = -1;
        for (int i = 0; i < tasks_count; i++) {
            if (!used[i] && in_degree[i] == 0) {
                candidate = i;
                break; 
            }
        }
        if (candidate == -1) {
            // No task found with in_degree=0 => cycle
            printf("cycle\n");
            // cleanup
            goto cleanup;
        }
        // Use candidate
        used[candidate] = 1;
        topological[topo_idx++] = candidate;
        used_count++;

        // Decrement in_degree of its neighbors
        AdjList *al = &adj[candidate];
        for (int k = 0; k < al->size; k++) {
            int neigh = al->neighbors[k];
            in_degree[neigh]--;
        }
    }

    // If we get here, we have a valid topological ordering
    for (int i = 0; i < topo_idx; i++) {
        printf("%s\n", unique_tasks[topological[i]]);
    }

cleanup:
    // Cleanup memory
    for (int i = 0; i < tasks_count; i++) {
        free(adj[i].neighbors);
    }
    free(adj);
    free(in_degree);
    free(used);
    free(topological);

    for (int i = 0; i < line_count; i++) {
        free(lines[i]);
    }
    free(lines);

    // note: unique_tasks[i] themselves are duplicates from lines[] or newly allocated
    // be careful not to double-free
    // But we used `strdup()` for insertion, so each unique task is unique.
    for (int i = 0; i < tasks_count; i++) {
        free(unique_tasks[i]);
    }
    free(unique_tasks);

    return 0;
}
