
# A5: CPU Scheduler Simulator

You will write a program named schsim that simulates the CPU scheduler policies outlined in Chapter 9 of the Operating Systems book. You will write this program in Zig. You must write a Makefile such that navigating into the directory and executing make will generate the program.
Input File Format

### Input File Format

The input file will be a .csv containing a list of processes, at which CPU cycle they arrive, how many cycles they take to complete and an optional list of I/O times and how many cycles that I/O burst takes:

```text
"A", 0, 3
"B", 2, 6
, 3, 2
"C", 4, 4
"D", 6, 5
"E", 8, 2
```

### Architecture

Each line in the file will either begin with a " character indicating it is a process or a , character indicating it is an I/O burst for the preceding process.
Architecture

[scheduler_map](./scheduler_map.png)

Here is the suggested architecture. When the __CPU__ cycle clock is equal to the arrival time for a process in the __Arrival Queue__, it is moved from there into the __Ready Queue__. When a process is in any blue queue, its time spent waiting increases. When a process is inside the __I/O Wait Queue__, its current I/O burst time decreases. When a process is in the __CPU__, its remaining time for service decreases (you need to remember the initial service time for output). When a process inside the __I/O Wait Queue__ has its current I/O burst time reach zero, it is moved from there to the __Ready__. When a process in the __CPU__ reaches zero remaining time for service, it is moved from there into the __Finish Queue__.

I will be looking for these major components in your program. They must be easily identifiable (objects or structs used). I will also be looking for a select() function that obtains a process from the Ready Queue according to the selected scheduler type and a tick() or cycle() function that advances the CPU (and related values, such as time spent waiting for other processes).

The program must implement all of the schedulers outlined in Chapter 9 of the __Operating Systems__ book:

    FF: First-Come-First-Served
    RR: Round Robin (with settable quantum)
    SP: Shortest Process Next
    SR: Shortest Remaining Time
    HR: Highest Response Ratio Next
    FB: Feedback (with settable quantum)

The program will accept a switch `-s` which selects which scheduler to simulate, an optional time quantum `-q` and an input and output filename:

```bash
./schsim -s FF -q 2 input.csv output.csv
```

If the optional time quantum is provided for a selected scheduler that doesn't require it, the program ignores that switch and runs normally. For the feedback scheduling policy, the quantum is only allowed to be 1 or 2 meaning q = 1 and q = 2 quantum values from the book, respectively.
Output File Format

### Output File Format

The output file will look similar to the input file, but will have added the process start time, finish time, turnaround time, normalized turnaround time (as a float with 2 decimal points) and time spent in wait for each of the processes. Finally it will list the mean turnaround time and the mean normalized turnaround time.

```text
"A", 0, 3, 0, 3, 3, 1.00
"C", 4, 4, 6, 10, 6, 1.50
"B", 2, 6, 3, 13, 11, 1.83
"D", 6, 5, 13, 18, 12, 2.40
"E", 8, 2, 18, 20, 12, 6.00
8.80, 2.55
```
