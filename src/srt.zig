pub fn SRT(comptime Scheduler: type) type {

    return struct { 
        const Self = @This();

        pub fn tick(self: *Self, gpa: std.mem.Allocator) !bool {

            var new_arrivals: bool = false                         // modded to add new_arrivals queue
            const index = loop: for (self.arrival_que.items) |p, i| {
            if (p.arrival_time <= self.clock) {
                break :loop i; }
            } else return false;
            self.ready_que.append(self.arrival_que.orderedRemove(index)) catch return false;
            new_arrivals = true;
            return true;


            // not sure if top is the same as this //
            // if (self.nextToReadyQueue()) {
            //     new_arrivals = true;
            // }

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
                } 
                
                else if (new_arrivals == true) {      // shorter remaining time algo
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
                wait.io_bursts.items[0][1] -= 1;
                if (wait.io_bursts.Queue.peek()[1] <= 0) {
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
        }
    }
}