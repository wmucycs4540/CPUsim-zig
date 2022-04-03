import csv

from .proc import Proc
from .queue import Queue


class Scheduler:
    def __init__(self, file, name, func, field, init):
        self.arrival = Queue()
        self.ready = Queue()
        self.io_wait = Queue()
        self.finished = Queue()
        self.in_context = None
        self.clock = 0
        self.done = True
        self.total_procs = 0
        self.selection_func = func
        self.selection_field = field
        self.selection_init = init
        self.name = name

        last = None
        with open(file, newline="") as f:
            rows = csv.reader(f)
            for row in rows:
                if row[0] != "":
                    last = Proc(row[0], int(row[1]), int(row[2]))
                    self.arrival.append(last)
                else:
                    last.io_bursts.enque([int(row[1]), int(row[2])])
        self.total_procs = len(self.arrival)

    def run(self):
        self.done = False
        while not self.done:
            self.tick()

    def tick(self):
        # enter any arrivals into ready queue
        while self.arrival.peek() is not None:
            if self.arrival.peek().arrival_time <= self.clock:
                self.ready.enque(self.arrival.deque())
            else:
                break

        # select process if CPU is idle
        if self.in_context is None:
            self.in_context = self.select()
        # switch to next available process and finish current
        elif self.in_context.remaining_time <= 0:
            self.in_context.finish_time = self.clock
            self.finished.enque(self.in_context)
            self.in_context = self.select()
        elif len(self.in_context.io_bursts) > 0:
            if (self.in_context.service_time - self.in_context.remaining_time) == self.in_context.io_bursts.peek()[0]:
                self.io_wait.enque(self.in_context)
                self.in_context = self.select()

        if len(self.finished) == self.total_procs:
            self.done = True
            return

        # work on current process
        self.in_context.remaining_time -= 1

        # update all queue occupy times
        # for p in self.schedule:
        #    p.time_in_schedule += 1

        for p in self.ready:
            p.time_in_ready += 1

        to_remove = []
        for i, p in enumerate(self.io_wait):
            p.time_in_io_wait += 1
            # reduce I/O burst time
            p.io_bursts.peek()[1] -= 1
            if p.io_bursts.peek()[1] <= 0:
                p.io_bursts.deque()
                # remember which ones are done
                to_remove.append(i)

        # move I/O finished processes to ready queue
        for i in to_remove:
            self.ready.enque(self.io_wait.deque_at(i))

        # finally, update clock
        self.clock += 1

    def select(self):
        if len(self.ready) <= 0:
            return None
        else:
            acc = self.selection_init
            index = 0
            for i, e in enumerate(self.ready):
                if self.selection_func(e, acc):
                    acc = self.selection_field(e)
                    index = i
            p: Proc = self.ready.deque_at(index)
            if not p.started:
                p.start_time = self.clock
                p.started = True
            return p

    def dump(self, file):
        filename = f"{self.name[0]}_{file}"
        with open(filename, "w") as f:
            tt: float = 0.0
            tn: float = 0.0
            p: Proc
            for p in self.finished:
                f.write(f"\"{p.id}\",")
                f.write(f"{p.arrival_time},")
                f.write(f"{p.service_time},")
                f.write(f"{p.start_time},")
                f.write(f"{p.total_wait()},")
                f.write(f"{p.finish_time},")
                f.write(f"{p.turnaround_time()},")
                tt += p.turnaround_time()
                f.write(f"{p.norm_turnaround():.02f}")
                tn += p.norm_turnaround()
                f.write("\n")
            tt /= self.total_procs
            tn /= self.total_procs
            f.write(f"{tt:.02f},{tn:.02f}")

    def __str__(self):
        tt: float = 0.0
        tn: float = 0.0
        r: str = f"*** {self.name} ***\n"
        r     += "        | Arrival |  Service  |            | Finish | Turnaround |\n"
        r     += "Process |  Time   | Time (Ts) | Start Time |  Time  |  Time (Tr) |  Tr/Ts\n"
        r     += "—————————————————————————————————————————————————————————————————————————\n"
        for p in sorted(self.finished, key=lambda e: e.id):
            tt += p.turnaround_time()
            tn += p.norm_turnaround()
            r += f"{p}\n"
        tt /= self.total_procs
        tn /= self.total_procs
        r     += "—————————————————————————————————————————————————————————————————————————\n"
        r     += "Mean                                                   {0: ^9.02f} | {1: =6.02f}\n".format(tt, tn)

        return r
