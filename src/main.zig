const std = @import("std");
const print = std.debug.print;
const Queue = @import("./queue.zig").Queue;

const Error = error {
    InvalidArgs,
    InvalidInput,
    ParseInt,
};

const Proc = struct {
    const Self = @This();

    pid: []const u8,
    arrival_time: u64,
    service_time: u64,
    start_time: u64 = 0,
    started: bool = false,
    remaining_time: u64,
    finish_time: u64 = 0,
    time_in_ready: u64 = 0,
    time_in_io_wait: u64 = 0,
    time_in_cpu: u64 = 0,
    io_bursts: std.ArrayList([2] u64),

    pub fn init(gpa: std.mem.Allocator, pid: []const u8, arrival: u64, service: u64) Self {
        return Self {
            .pid = pid,
            .arrival_time = arrival,
            .service_time = service,
            .remaining_time = service,
            .io_bursts = std.ArrayList([2] u64).init(gpa),
        };
    }

    pub fn turnaround_time(self: Self) u64 {
        return self.finish_time - self.arrival_time;
    }
    pub fn norm_turnaround(self: Self) f32 {
        return @intToFloat(f32, self.turnaround_time()) / @intToFloat(f32, self.service_time);
    }

    pub fn total_wait(self: Self) u64 {
        return self.time_in_ready + self.time_in_io_wait;
    }
};



const SchedulerKind = enum {
    ff, rr, sp, sr, hr, fb
};

const SchedulerMeta = union(SchedulerKind) {
    ff: struct {
        select: fn(*Scheduler) ?Proc = Scheduler.ffSelect,
    },
    rr: struct {
        select: fn(*Scheduler) ?Proc = Scheduler.rrSelect,
        quant: u8,
    },
    sp: struct {
        select: fn(*Scheduler) ?Proc = Scheduler.spSelect,
    },
    sr: struct {
        select: fn(*Scheduler) ?Proc = Scheduler.srSelect,
    },
    hr: struct {
        select: fn(*Scheduler) ?Proc = Scheduler.hrSelect,
    },
    fb: struct {
        select: fn(*Scheduler) ?Proc = Scheduler.fbSelect,
        quant: u8,
    }
};


const Scheduler = struct {
    const Self = @This();

    arrival_que: Queue(Proc),
    ready_que: Queue(Proc),
    iowait_que: Queue(Proc),
    finished: Queue(Proc),

    current: ?Proc = null,

    clock: u64 = 0,
    total_procs: u64 = 0,
    kind: SchedulerMeta,

    pub fn init(gpa: std.mem.Allocator, kind: SchedulerMeta, arrival: Queue(Proc)) Self {
        return Self {
            .kind = kind,
            .arrival_que = arrival,
            .ready_que = Queue(Proc).init(gpa),
            .iowait_que = Queue(Proc).init(gpa),
            .finished = Queue(Proc).init(gpa),
        };
    }
    pub fn deinit(self: Self) void {
        self.arrival_que.deinit(); self.ready_que.deinit();
        self.iowait_que.deinit(); self.finished.deinit();
    }

    pub fn print_verbose(self: Self) void {
        const none: []const u8 = "";
        const comma: []const u8 = ", ";
        print("{:>3}: {s} | arrived = {{", .{self.clock, self.current.?.pid });
        const alen = self.arrival_que.len();
        for (self.arrival_que.iter()) |a, i| {
            const end = if ((i + 1) == alen) none else comma;
            print("{s}{s}", .{a.pid, end});
        }
        print("}}", .{});
        print(" ready = {{", .{});
        const rlen = self.ready_que.len();
        for (self.ready_que.iter()) |r, i| {
            const end = if ((i + 1) == rlen) none else comma;
            print("{s}{s}", .{r.pid, end});
        }
        print("}}", .{});
        print(" io = {{", .{});
        const ilen = self.iowait_que.len();
        for (self.iowait_que.iter()) |io, i| {
            const end = if ((i + 1) == ilen) none else comma;
            print("{s}{s}", .{io.pid, end});
        }
        print("}}\n", .{});
    }

    /// First-Come-First-Served Scheduler
    fn ffSelect(self: *Self) ?Proc {
        if (self.ready_que.len() == 0) return null;
        var cmp = @as(u64, 0);
        var idx = @as(u64, 0);
        for (self.ready_que.iter()) |proc, i| {
            if (proc.total_wait() > cmp) {
                cmp = proc.total_wait();
                idx = i;
            }
        }
        return self.ready_que.deque_at(idx);
    }

    /// Round Robbin (with quant)
    fn rrSelect(self: *Self) ?Proc {
        if (self.ready_que.len() == 0) return null;
        return self.ready_que.deque();
    }

    /// Shortest Process Next Scheduler
    fn spSelect(self: *Self) ?Proc {
        if (self.ready_que.len() == 0) return null;
        var cmp = @as(u64, std.math.maxInt(u64));
        var idx = @as(u64, 0);
        for (self.ready_que.iter()) |proc, i| {
            if (proc.service_time < cmp) {
                cmp = proc.service_time;
                idx = i;
            }
        }
        return self.ready_que.deque_at(idx);
    }

    /// Shortest Remaining Time
    fn srSelect(self: *Self) ?Proc {
        if (self.ready_que.len() == 0) return null;
        var cmp = @as(u64, std.math.maxInt(u64));
        var idx = @as(u64, 0);
        for (self.ready_que.iter()) |proc, i| {
            if (proc.remaining_time < cmp) {
                cmp = proc.remaining_time;
                idx = i;
            }
        }
        return self.ready_que.deque_at(idx);
    }

    /// Highest Response Ratio Next
    fn hrSelect(self: *Self) ?Proc {
        if (self.ready_que.len() == 0) return null;
        var cmp = @as(u64, 0);
        var idx = @as(u64, 0);
        for (self.ready_que.iter()) |proc, i| {
            const check = (proc.total_wait() + proc.service_time) / proc.service_time;
            if (check > cmp) {
                cmp = check;
                idx = i;
            }
        }
        return self.ready_que.deque_at(idx);
    }

    /// Facebook
    fn fbSelect(self: *Self) ?Proc {
        _ = self;
        unreachable;
    }

    pub fn nextToReadyQueue(self: *Self) bool {
        const index = loop: for (self.arrival_que.iter()) |p, i| {
            if (p.arrival_time <= self.clock) {
                break :loop i;
            }
        } else return false;

        self.ready_que.enque(self.arrival_que.deque_at(index).?);
        return true;
    }

    fn select(self: *Self) ?Proc {
        var proc = switch (self.kind) {
            .ff => |ff_sel| ff_sel.select(self),
            .rr => |rr_sel| rr_sel.select(self),
            .sp => |sp_sel| sp_sel.select(self),
            .sr => |sr_sel| sr_sel.select(self),
            .hr => |hr_sel| hr_sel.select(self),
            // .fb => |fb_sel| fb_sel.select(self),
            else => unreachable,
        };
        if (proc) |*p| {
            if (!p.started) {
                p.start_time = self.clock;
                p.started = true;
            }
        }
        return proc;
    }

    pub fn tick(self: *Self, gpa: std.mem.Allocator) !bool {
        const new_arrival = self.nextToReadyQueue();

        if (self.current == null) {
            self.current = self.select();
        } else if (self.current) |*curr| {
            if (curr.remaining_time <= 0) {
                curr.finish_time = self.clock;
                self.finished.enque(curr.*);
                self.current = self.select();
            } else if (curr.io_bursts.items.len > 0
                and (curr.service_time - curr.remaining_time) == curr.io_bursts.items[0][0])
            {
                self.iowait_que.enque(curr.*);
                self.current = self.select();
            } else if (self.kind == SchedulerKind.rr and curr.time_in_cpu == self.kind.rr.quant) {
                curr.time_in_cpu = 0;
                self.ready_que.enque(curr.*);
                self.current = self.select();
            } else if (self.kind == SchedulerKind.sr and new_arrival) {
                self.ready_que.enque(curr.*);
                self.current = self.select();
            }
        }

        if (self.finished.len() == self.total_procs) {
            return false;
        }

        self.print_verbose();

        self.current.?.remaining_time -= 1;
        self.current.?.time_in_cpu += 1;

        for (self.ready_que.iter()) |*ready| {
            ready.time_in_ready += 1;
        }

        var removed = std.ArrayList(u64).init(gpa);
        defer removed.deinit();
        for (self.iowait_que.iter()) |*wait, i| {
            wait.time_in_io_wait += 1;
            wait.io_bursts.items[0][1] -= 1;
            if (wait.io_bursts.items[0][1] <= 0) {
                _ = wait.io_bursts.orderedRemove(0);
                try removed.append(i);
            }
        }

        for (removed.items) |idx| {
            self.ready_que.enque(self.iowait_que.deque_at(idx).?);
        }

        self.clock += 1;
        return true;
    }

    pub fn run(self: *Self, gpa: std.mem.Allocator) !void {
        self.total_procs = self.arrival_que.len();
        while (try self.tick(gpa)) {}
    }

    pub fn resultToString(self: Self, gpa: std.mem.Allocator) ![]u8 {
        var string = std.ArrayList(u8).init(gpa);
        var tt = @as(f32, 0.0);
        var tn = @as(f32, 0.0);
        for (self.finished.iter()) |proc| {
            try string.appendSlice(try std.fmt.allocPrint(gpa, "\"{s}\", ", .{proc.pid}));
            try string.appendSlice(try std.fmt.allocPrint(gpa, "{}, ", .{proc.arrival_time}));
            try string.appendSlice(try std.fmt.allocPrint(gpa, "{}, ", .{proc.service_time}));
            try string.appendSlice(try std.fmt.allocPrint(gpa, "{}, ", .{proc.start_time}));
            try string.appendSlice(try std.fmt.allocPrint(gpa, "{}, ", .{proc.total_wait()}));
            try string.appendSlice(try std.fmt.allocPrint(gpa, "{}, ", .{proc.finish_time}));
            try string.appendSlice(try std.fmt.allocPrint(gpa, "{}, ", .{proc.turnaround_time()}));
            try string.appendSlice(try std.fmt.allocPrint(gpa, "{d:.2}", .{proc.norm_turnaround()}));
            try string.appendSlice("\n");
            tt += @intToFloat(f32, proc.turnaround_time());
            tn += proc.norm_turnaround();
        }
        tt /= @intToFloat(f32, self.total_procs);
        tn /= @intToFloat(f32, self.total_procs);
        try string.appendSlice(try std.fmt.allocPrint(gpa, "{d:.2}, {d:.2}", .{tt, tn}));
        return string.toOwnedSlice();
    }
};

pub fn main() !void {
    var gpa = std.testing.allocator;

    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    var input_idx: u8 = 3;
    var output_idx: u8 = 4;
    var kind: SchedulerMeta = undefined;
    if (std.mem.eql(u8, args[1], "-s")) {
        if (std.mem.eql(u8, args[2], "FF")) kind = SchedulerMeta{ .ff = .{} }
        else if (std.mem.eql(u8, args[2], "RR")) {
            if (std.mem.eql(u8, args[3], "-q")) {
                input_idx += 2;
                output_idx += 2;
                const quant = try std.fmt.parseInt(u8, args[4], 10);
                kind = SchedulerMeta{ .rr = .{ .quant = quant } };
            }
        }
        else if (std.mem.eql(u8, args[2], "SP")) kind = SchedulerMeta{ .sp = .{} }
        else if (std.mem.eql(u8, args[2], "SR")) kind = SchedulerMeta{ .sr = .{} }
        else if (std.mem.eql(u8, args[2], "HR")) kind = SchedulerMeta{ .hr = .{} }
        else if (std.mem.eql(u8, args[2], "FB")) {
            if (std.mem.eql(u8, args[3], "-q")) {
                input_idx += 2;
                output_idx += 2;
                const quant = try std.fmt.parseInt(u8, args[4], 10);
                kind = SchedulerMeta{ .fb = .{ .quant = quant } };
            }
        }
        else return Error.InvalidArgs;
    }

    const input = args[input_idx];
    const output = args[output_idx];

    const file = try std.fs.cwd().openFile(input, .{ .mode = .read_only });
    defer file.close();
    const file_reader = std.io.bufferedReader(file.reader()).reader();

    var processes = Queue(Proc).init(gpa);
    defer processes.deinit();
    while (try file_reader.readUntilDelimiterOrEofAlloc(gpa, '\n', std.math.maxInt(u16))) |line| {
        if (std.mem.startsWith(u8, line, "#") or std.mem.startsWith(u8, line, "\n") or line.len == 0) {
            continue;
        }
        var splitter = std.mem.split(u8, line, ",");
        var proc_pid = splitter.next() orelse return Error.InvalidInput;
        // Strip BOM (byte order mark) from input_simple.csv
        if (std.mem.startsWith(u8, proc_pid, @as([]const u8, &.{239, 187, 191 }))) {
            proc_pid = proc_pid[3..];
        }
        proc_pid = std.mem.trim(u8, proc_pid, "\"");

        var ariv_str = splitter.next() orelse return Error.InvalidInput;
        ariv_str = std.mem.trim(u8, ariv_str, " ");
        const arrival = std.fmt.parseInt(u64, ariv_str, 10) catch return Error.ParseInt;
        var serv_str = splitter.next() orelse return Error.InvalidInput;
        serv_str = std.mem.trim(u8, serv_str, " ");
        const service = std.fmt.parseInt(u64, serv_str, 10) catch return Error.ParseInt;

        if (std.mem.eql(u8, proc_pid, " ") or proc_pid.len == 0) {
            const last = processes.len() - 1;
            try processes.items.items[last].io_bursts.append(.{arrival, service});
        } else if (proc_pid.len == 1) {
            const p = Proc.init(gpa, try gpa.dupe(u8, proc_pid), arrival, service);
            processes.enque(p);
        } else {
            return Error.InvalidInput;
        }
    }

    var sched = Scheduler.init(gpa, kind, processes);
    try sched.run(gpa);
    const info = try sched.resultToString(gpa);

    print("{s}\n{s}", .{info, output});

    // const out_file = try std.fs.cwd().createFile(output, .{ .read = true });
    // defer out_file.close();

    // _ = try out_file.writeAll(info);
}
