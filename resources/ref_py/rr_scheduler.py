from .scheduler import Scheduler
from .proc import Proc


class RRScheduler(Scheduler):
    def __init__(self, file, name, init, quantum):
        super().__init__(file, name, None, None, init)
        self.quantum = quantum

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
        # switch out process if it needs I/O
        elif len(self.in_context.io_bursts) > 0 and \
        ((self.in_context.service_time - self.in_context.remaining_time) == self.in_context.io_bursts.peek()[0]):
            self.io_wait.enque(self.in_context)
            self.in_context = self.select()
        # switch out process at each time quantum
        elif self.in_context.time_in_cpu == self.quantum:
            self.in_context.time_in_cpu = 0
            self.ready.enque(self.in_context)
            self.in_context = self.select()

        if len(self.finished) == self.total_procs:
            self.done = True
            return

        # work on current process
        self.in_context.remaining_time -= 1
        self.in_context.time_in_cpu += 1

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
            p: Proc = self.ready.deque()
            if not p.started:
                p.start_time = self.clock
                p.started = True
            return p
