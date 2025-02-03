; rosetta.asm – Full topological sort solution for the “rosetta” problem.
; Reads dependency pairs from standard input (each two lines: first is a task, second is its dependency).
; Builds a directed graph and outputs a valid topological order (with lexicographical tie‐breaking)
; or the single word "cycle" if a cycle exists.
;
; Assumptions:
;   - Maximum input size: 64KB.
;   - Maximum lines: 256.
;   - Maximum distinct tasks: 100.
;   - Maximum length of a task: 127 characters.
;   - Maximum dependents per task: 10.
;
; Uses Win64 API: GetStdHandle, ReadFile, WriteFile, ExitProcess.
; Assemble with NASM and link with GCC.
;
; (This code is provided “as is” and is intended as an advanced demonstration.)

; ----------------------
; CONSTANTS & EXTERNALS
; ----------------------
SECTION .data
    ; Standard handle constants (as signed 32‐bit values)
    STDIN_HANDLE    dd -10
    STDOUT_HANDLE   dd -11

    cycle_str       db "cycle", 10, 0
    error_odd       db "Error: odd number of lines", 10, 0

    newline         db 10

SECTION .bss
    ; Input buffer (64 KB)
    inputBuffer     resb 65536
    bytesRead       resd 1

    ; Array for pointers to each line (max 256 lines, 8 bytes each)
    linesArray      resq 256
    lineCount       resq 1

    ; Tasks – up to 100 distinct tasks.
    ; tasksArray will hold pointers to task strings.
    tasksArray      resq 100
    tasksCount      resq 1
    ; Storage for task strings (each max 128 bytes)
    tasksStorage    resb 12800       ; 100 * 128
    tasksStorageOff resq 1           ; current offset into tasksStorage

    ; For each task, store its in-degree (100 integers)
    indegreeArray   resd 100

    ; For each task, store indices of dependents.
    ; Each task may have up to 10 dependents → 100 * 10 = 1000 integers.
    outEdges        resd 1000
    ; For each task, number of dependents (100 integers)
    outCounts       resd 100

    ; A dummy variable for WriteFile’s bytes-written.
    dummy           resd 1

SECTION .text
    global main
    extern GetStdHandle
    extern ReadFile
    extern WriteFile
    extern ExitProcess

; ----------------------
; main
; ----------------------
main:
    ; Initialize tasks count and tasks storage offset to 0.
    mov qword [tasksCount], 0
    mov qword [tasksStorageOff], 0

    ; --- Read all input from STDIN into inputBuffer ---
    ; Get STDIN handle.
    mov ecx, STDIN_HANDLE
    call GetStdHandle    ; rax = STDIN handle
    mov rbx, rax         ; save STDIN handle in rbx

    ; Call ReadFile(STDIN, inputBuffer, 65536, &bytesRead, NULL)
    mov rcx, rbx               ; handle
    lea rdx, [inputBuffer]     ; buffer
    mov r8, 65536              ; bytes to read
    lea r9, [bytesRead]        ; pointer to bytesRead
    call ReadFile

    ; --- Parse inputBuffer into lines (null-terminate lines) ---
    call parse_lines

    ; --- Check that the number of lines is even ---
    mov rax, [lineCount]
    test rax, 1
    jnz odd_error

    ; --- Process dependency pairs ---
    ; For every two lines: first line = task, second line = dependency.
    ; For each pair, we add an edge: (dependency -> task) and update in-degrees.
    mov rcx, 0           ; rcx will index into linesArray
process_pairs:
    mov rax, [lineCount]
    cmp rcx, rax
    jge pairs_done

    ; Get pointer to first line (the task)
    mov rdx, rcx
    shl rdx, 3                  ; index * 8
    lea r8, [linesArray + rdx]
    mov rdi, [r8]               ; rdi = pointer to task string
    call find_or_add_task       ; returns index in eax
    mov r12d, eax               ; r12 = task index

    ; Get pointer to second line (the dependency)
    add rcx, 1                  ; move to second line
    mov rdx, rcx
    shl rdx, 3
    lea r8, [linesArray + rdx]
    mov rdi, [r8]               ; rdi = pointer to dependency string
    call find_or_add_task       ; returns dependency index in eax
    mov r13d, eax               ; r13 = dependency index

    ; Add edge: dependency -> task.
    ; (i.e. add task index (r12) to dependency’s outEdges list)
    mov ecx, r13d             ; use ecx = dependency index
    mov edx, dword [outCounts + rcx*4]  ; current count for this dependency
    cmp edx, 10
    jge skip_edge             ; if already 10 dependents, skip (should not occur)
    ; Compute outEdges index: index = (dependency*10 + current count)
    mov r10, r13            ; use full 64-bit register for dependency index
    imul r10, r10, 10       ; multiply r10 by 10
    add r10, rdx            ; r10 = slot index (dependency*10 + current count)
    mov dword [outEdges + r10*4], r12d  ; store task index into outEdges
    inc dword [outCounts + rcx*4]         ; increment dependency’s outCount

    ; Increment in-degree for task.
    mov ecx, r12d
    inc dword [indegreeArray + rcx*4]

skip_edge:
    ; Advance rcx by one more to move past the pair.
    add rcx, 1
    jmp process_pairs

pairs_done:
    ; --- Topological Sort ---
    call topological_sort

    ; If we reach here, sorting was successful; exit normally.
    mov ecx, 0
    call ExitProcess

odd_error:
    ; Write error message and exit.
    mov ecx, STDOUT_HANDLE
    call GetStdHandle
    mov rcx, rax         ; rcx = STDOUT handle
    lea rdx, [error_odd]
    mov r8, 28           ; approximate length of error message
    lea r9, [dummy]
    call WriteFile
    mov ecx, 1
    call ExitProcess

; ----------------------
; parse_lines:
; Scans inputBuffer (of length [bytesRead]) and replaces newline (0x0A) with 0.
; Stores pointer to each line in linesArray and sets lineCount.
; ----------------------
parse_lines:
    lea rsi, [inputBuffer]     ; pointer to inputBuffer
    mov ecx, [bytesRead]       ; ecx = number of bytes read
    xor rdx, rdx               ; rdx = line counter index
    ; Set first line pointer.
    lea rax, [linesArray]
    mov [rax], rsi

parse_loop:
    test ecx, ecx
    jz parse_done
    mov al, byte [rsi]
    cmp al, 10
    jne not_newline
    ; Replace newline with 0.
    mov byte [rsi], 0
    ; If not at end, store pointer to next character.
    lea rdi, [rsi+1]
    mov rbx, rdx
    inc rbx
    lea r8, [linesArray]
    mov [r8 + rbx*8], rdi
    inc rdx
not_newline:
    inc rsi
    dec ecx
    jmp parse_loop
parse_done:
    ; The number of lines is (rdx + 1).
    inc rdx
    mov [lineCount], rdx
    ret

; ----------------------
; find_or_add_task:
; Input: rdi = pointer to a null-terminated task string.
; Returns: eax = index of task in tasksArray.
; (Uses a linear search over tasksArray; if not found, copies the string into tasksStorage.)
; ----------------------
find_or_add_task:
    push rdi                ; save input pointer on stack
    mov rsi, rdi            ; rsi = input string pointer
    ; Get current tasksCount.
    mov rax, [tasksCount]
    mov r8, rax             ; r8 = tasksCount
    cmp r8, 0
    je add_new_task
    xor rcx, rcx            ; rcx = loop index
find_loop:
    cmp rcx, r8
    jge add_new_task
    ; Get pointer from tasksArray[rcx].
    lea rdx, [tasksArray + rcx*8]
    mov rbx, [rdx]
    ; Compare the two strings.
    ; (Assume our string_compare expects first in rdi and second in rsi.)
    push rdx                ; save rdx
    mov rdi, rsi            ; first string is our input
    mov rsi, rbx            ; second string is the stored task
    call string_compare     ; result in eax (0 if equal)
    pop rdx
    cmp eax, 0
    je found_task
    inc rcx
    jmp find_loop
found_task:
    mov eax, ecx            ; return found index
    ret

add_new_task:
    ; rcx will be the new task index (equal to current tasksCount).
    mov rax, [tasksCount]
    mov rcx, rax

    ; Get current tasksStorage offset.
    mov rdx, [tasksStorageOff]
    ; Calculate destination address = tasksStorage + offset.
    lea rdi, [tasksStorage + rdx]
    ; rsi already holds input string.
copy_loop:
    mov al, byte [rsi]
    mov byte [rdi], al
    cmp al, 0
    je copy_done
    inc rsi
    inc rdi
    jmp copy_loop
copy_done:
    ; Save pointer to the new task in tasksArray.
    lea rax, [tasksStorage + rdx]
    lea rbx, [tasksArray]
    mov [rbx + rcx*8], rax
    ; Compute length = (rdi - (tasksStorage + rdx)) and add 1.
    lea r8, [tasksStorage + rdx]
    mov r9, rdi
    sub r9, r8
    inc r9
    add qword [tasksStorageOff], r9

    ; Initialize in-degree and outCount to 0.
    mov dword [indegreeArray + rcx*4], 0
    mov dword [outCounts + rcx*4], 0

    ; Increment tasksCount.
    inc qword [tasksCount]
    mov eax, ecx
    ret

; ----------------------
; string_compare:
; Compares two null-terminated strings.
; Expects first string in rdi and second string in rsi.
; Returns eax = 0 if equal, negative if first < second, positive if first > second.
; ----------------------
string_compare:
    push rdi
    push rsi
scmp_loop:
    mov al, byte [rdi]
    mov bl, byte [rsi]
    cmp al, bl
    jne scmp_diff
    cmp al, 0
    je scmp_equal
    inc rdi
    inc rsi
    jmp scmp_loop
scmp_diff:
    movzx eax, al
    movzx ebx, bl
    sub eax, ebx
    jmp scmp_done
scmp_equal:
    xor eax, eax
scmp_done:
    pop rsi
    pop rdi
    ret

; ----------------------
; topological_sort:
; Implements the topological sort:
;   Repeat (tasksCount times):
;     – Find the lexicographically smallest task with in-degree 0.
;     – If none found, output "cycle" and exit.
;     – Otherwise, output the task, mark it processed (set in-degree = -1),
;         and for each dependent, decrement its in-degree.
; ----------------------
topological_sort:
    ; rbx = tasksCount.
    mov rbx, [tasksCount]
    xor rcx, rcx          ; count of processed tasks = 0

    ; Load base addresses of outEdges and indegreeArray into r14 and r15.
    lea r14, [outEdges]
    lea r15, [indegreeArray]

topo_loop:
    cmp rcx, rbx
    jge topo_done         ; if processed count equals tasksCount, we are done

    ; Find candidate: among tasks with indegree==0, choose lexicographically smallest.
    mov r8, -1            ; r8 will hold candidate index; -1 means none found.
    xor r9, r9            ; loop index = 0
find_candidate:
    cmp r9, rbx
    jge candidate_done
    mov edx, dword [indegreeArray + r9*4]
    cmp edx, 0
    jne skip_candidate
    ; Found a candidate.
    cmp r8, -1
    je set_candidate
    ; Compare tasks[r9] with tasks[r8]:
    lea rdi, [tasksArray + r9*8]
    mov rdi, [rdi]
    lea rsi, [tasksArray + r8*8]
    mov rsi, [rsi]
    call string_compare
    cmp eax, 0
    jl set_candidate   ; if tasks[r9] is lexicographically smaller, update candidate.
    jmp skip_candidate
set_candidate:
    mov r8, r9
skip_candidate:
    inc r9
    jmp find_candidate
candidate_done:
    cmp r8, -1
    je cycle_detected   ; no candidate with indegree==0 → cycle exists

    ; Candidate found in r8. Output its string.
    lea rdi, [tasksArray + r8*8]
    mov rdi, [rdi]
    call print_string
    ; Output a newline.
    lea rdi, [newline]
    call print_string

    ; Mark candidate as processed by setting its in-degree to -1.
    mov dword [indegreeArray + r8*4], -1

    ; For each dependent of candidate:
    mov ecx, dword [outCounts + r8*4]    ; number of dependents.
    cmp ecx, 0
    je candidate_done_loop
    xor rsi, rsi
dependent_loop:
    cmp rsi, ecx
    jge candidate_done_loop
    ; Compute index = (r8 * 10 + rsi)
    mov r10, r8
    imul r10, r10, 10      ; multiply r10 by 10
    add r10, rsi
    ; Compute effective address for outEdges:
    lea r12, [r14 + r10*4]
    mov edx, dword [r12]   ; edx now holds the dependent task index
    ; Compute effective address for indegreeArray[dependent_index]:
    mov r11, rdx         ; copy dependent index into r11
    shl r11, 2           ; r11 = dependent_index * 4
    lea r12, [r15 + r11] ; compute address of indegreeArray[dependent_index]
    mov eax, dword [r12] ; load in-degree for the dependent
    cmp eax, 0
    jle skip_dependent
    ; Decrement the in-degree:
    lea r12, [r15 + r11]
    dec dword [r12]
skip_dependent:
    inc rsi
    jmp dependent_loop
candidate_done_loop:
    inc rcx                      ; one more task processed.
    jmp topo_loop
topo_done:
    ret

cycle_detected:
    ; Output "cycle" and exit.
    lea rdi, [cycle_str]
    call print_string
    mov ecx, 0
    call ExitProcess

; ----------------------
; print_string:
; Expects: rdi = pointer to a null-terminated string.
; Writes the string to STDOUT.
; ----------------------
print_string:
    ; Get STDOUT handle.
    mov ecx, STDOUT_HANDLE
    call GetStdHandle
    mov rbx, rax               ; rbx = STDOUT handle
    ; Compute string length.
    push rdi
    call string_length         ; returns length in rax
    pop rdi
    mov rdx, rax             ; rdx = length
    ; Call WriteFile(STDOUT, rdi, rdx, &dummy, NULL)
    mov rcx, rbx             ; handle
    ; rdi already has pointer
    mov r8, rdx              ; number of bytes
    lea r9, [dummy]
    call WriteFile
    ret

; ----------------------
; string_length:
; Expects: rdi = pointer to null-terminated string.
; Returns: rax = length.
; ----------------------
string_length:
    xor rax, rax
strlen_loop:
    cmp byte [rdi + rax], 0
    je strlen_done
    inc rax
    jmp strlen_loop
strlen_done:
    ret
