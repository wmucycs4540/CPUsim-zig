from queue import Queue


class Proc:
    def __init__(self, proc_id, arrival_time, service_time):
        self.id = proc_id
        self.arrival_time = arrival_time
        self.service_time = service_time
        self.start_time = 0
        self.started = False
        self.remaining_time = service_time
        self.finish_time = 0
        self.time_in_ready = 0
        self.time_in_io_wait = 0
        self.time_in_cpu = 0
        self.io_bursts = Queue()

    def turnaround_time(self):
        return self.finish_time - self.arrival_time

    def norm_turnaround(self):
        return self.turnaround_time() / self.service_time

    def total_wait(self):
        return self.time_in_ready + self.time_in_io_wait

    def __str__(self):
        return "{0: <7} |  {1: ^6} |  {2: ^8} |  {3: ^9} |  {4: ^5} |  {5: ^9} | {6: =6.02f}".format(
            self.id,
            self.arrival_time,
            self.service_time,
            self.start_time,
            self.finish_time,
            self.turnaround_time(),
            round(self.norm_turnaround(), 2)
        )
