// Should be correct, followed rr_scheduler.py
pub fn RR(comptime Scheduler: type, quantum: u64) type {

    return struct {
        const Self = @This();
    
        pub fn tick(self: *Self, gpa: std.mem.Allocator) !bool {

            if (!self.nextToReadyQueue()) {
                return false;
            }

            if (self.current) |*curr| {
                if (curr.remaining_time <= 0) {
                    curr.finish_time = self.clock;
                    try self.finished.append(curr.*);
                    self.current = self.select();
                } else if (curr.io_bursts.items.len > 0 and
                    (curr.service_time - curr.remaining_time) == curr.io_bursts.items[0][0]
                ) {
                    try self.iowait_que.append(curr.*);
                    self.current = self.select();

                // added quantum algo
                } else if (curr.time_in_cpu == quantum) {
                    curr.time_in_cpu = 0
                    try self.ready_que.append(curr.*);
                    self.current = self.select();
                }
            } else {
                self.current = self.select();
            }

            if (self.finished.items.len == self.total_procs) {
                return false;
            }

            self.current.?.remaining_time -= 1;

            for (self.ready_que.items) |*ready| {
                ready.time_in_ready += 1;
            }

            var removed = std.ArrayList(u64).init(gpa);
            defer removed.deinit();
            for (self.iowait_que.items) |*wait, i| {
                wait.time_in_io_wait += 1;

                if (wait.io_bursts.items.len > 0) {
                    wait.io_bursts.items[0][1] -= 1;
                    if (wait.io_bursts.items[0][1] == 0) {
                        _ = wait.io_bursts.orderedRemove(0);
                        try removed.append(i);
                    }
                }
            }
            for (removed.items) |idx| {
                try self.ready_que.append(self.iowait_que.orderedRemove(idx));
            }

            self.clock += 1;
            return true;
            }

        pub fn select(self: Self, p: type) {
            if (self.ready_que.len <= 0) 
                return null
            else
                p = self.ready_que.Queue.deque()
                if (p.started == false)
                    p.start_time = clock
                    p.started = true
                return p
            }
    }
}