// helpers
const std = @import("std");
const print = std.debug.print;

const Error = error {
    InvalidArgs,
    InvalidInput,
    ParseInt,
};

// struct (to add start_t,fin_t, norm_tt)
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
    pub fn norm_turnaround(self: Self) u64 {
        return self.turnaround_time() / self.service_time;
    }

    pub fn total_wait(self: Self) u64 {
        return self.time_in_ready + self.time_in_io_wait;
    }
};

const SchedulerKind = enum {
    FF, RR, SP, SR, HR, FB
};

const Scheduler = struct {
    const Self = @This();

    arrival_que: std.ArrayList(Proc),
    ready_que: std.ArrayList(Proc),
    iowait_que: std.ArrayList(Proc),
    finished: std.ArrayList(Proc),
    clock: u64 = 0,
    total_procs: u64 = 0,
    kind: SchedulerKind,

    pub fn init(gpa: std.mem.Allocator, kind: SchedulerKind, arrival: std.ArrayList(Proc)) Self {
        return Self {
            .kind = kind,
            .arrival_que = arrival,
            .ready_que = std.ArrayList(Proc).init(gpa),
            .iowait_que = std.ArrayList(Proc).init(gpa),
            .finished = std.ArrayList(Proc).init(gpa),
        };
    }
    pub fn deinit(self: Self) void {
        self.arrival_que.deinit();
        self.ready_que.deinit();
        self.iowait_que.deinit();
        self.finished.deinit();
    }
};

pub fn main() !void {
    var gpa = std.testing.allocator;

    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);


    var input_idx: u8 = 3;
    var output_idx: u8 = 4;
    var kind: SchedulerKind = undefined;
    if (std.mem.eql(u8, args[1], "-s")) {
        if (std.mem.eql(u8, args[2], "FF")) kind = SchedulerKind.FF
        else if (std.mem.eql(u8, args[2], "RR")) {
            kind = SchedulerKind.RR;
            if (std.mem.eql(u8, args[3], "-q")) {
                input_idx += 2;
                output_idx += 2;
                _ = try std.fmt.parseInt(u8, args[4], 10);
            }
        }
        else if (std.mem.eql(u8, args[2], "SP")) kind = SchedulerKind.SP
        else if (std.mem.eql(u8, args[2], "SR")) kind = SchedulerKind.SR
        else if (std.mem.eql(u8, args[2], "HR")) kind = SchedulerKind.HR
        else if (std.mem.eql(u8, args[2], "FB")) {
            kind = SchedulerKind.FB;
            if (std.mem.eql(u8, args[3], "-q")) {
                input_idx += 2;
                output_idx += 2;
                _ = try std.fmt.parseInt(u8, args[4], 10);
            }
        }
        else return Error.InvalidArgs;
    }

    const input = args[input_idx];
    const output = args[output_idx];

    const file = try std.fs.cwd().openFile(input, .{ .mode = .read_only });
    defer file.close();
    const file_reader = std.io.bufferedReader(file.reader()).reader();

    var processes = std.ArrayList(Proc).init(gpa);
    defer processes.deinit();
    while (try file_reader.readUntilDelimiterOrEofAlloc(gpa, '\n', std.math.maxInt(u16))) |line| {
        var splitter = std.mem.split(u8, line, ",");

        const tok1 = splitter.next() orelse return Error.InvalidInput;

        const arrival = try std.fmt.parseInt(u64, splitter.next() orelse return Error.InvalidInput, 10);
        const service = try std.fmt.parseInt(u64, splitter.next() orelse return Error.InvalidInput, 10);

        if (std.mem.eql(u8, tok1, " ")) {
            const last = processes.items.len - 1;
            try processes.items[last].io_bursts.append(.{arrival, service});
        } else if (!std.mem.eql(u8, tok1, "")) {
            const p = Proc.init(gpa, try gpa.dupe(u8, tok1), arrival, service);
            try processes.append(p);
        } else {
            print("{s}\n", .{tok1});
            return Error.InvalidInput;
        }
    }

    var sched = Scheduler.init(gpa,kind, processes);

    for (sched.arrival_que.items) |p| {
        std.debug.print(
            "pid: {s}, arrival: {d}, service: {d}, total wait: {d}\n",
            .{ p.pid, p.arrival_time, p.service_time, p.total_wait() }
        );
    }

    const out_file = try std.fs.cwd().createFile(output, .{ .read = true });
    defer out_file.close();

    _ = try out_file.writeAll("Hello File!");
}
