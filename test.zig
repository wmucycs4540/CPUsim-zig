// helpers
const std = @import("std");
const print = std.debug.print;

// struct (to add start_t,fin_t, norm_tt)
const Data = struct { pid: []const u8 , at: u8, bt: u8, tt: u8};


// comparator functions - zig.sort
fn cmpByData(context: void, a: Data, b: Data) bool {
    _ = context;
    if (a.at < b.at) {
      return true;
    } else {
      return false;
    }
}



pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const allocator = arena.allocator();

    // modify to 64kb allocator (later)
    // const allocator = try std.heap.page_allocator.alloc(u32, 64000);

    var processes = std.ArrayList(Data).init(allocator);
    defer processes.deinit();

    const file = try std.fs.cwd().openFile("input.csv", .{ .mode = .read_only });
    defer file.close();

    const file_reader = std.io.bufferedReader(file.reader()).reader();
    while (try file_reader.readUntilDelimiterOrEofAlloc(allocator, '\n', std.math.maxInt(u16))) |line| {
        var splitter = std.mem.split(u8, line, ",");

        const tok1 = splitter.next() orelse return error.MissingField1;
        const tok2 = splitter.next() orelse return error.MissingField2;
        const tok3 = splitter.next() orelse return error.MissingField3;

        const p = Data{
            .pid = if (std.ascii.eqlIgnoreCase(tok1, " "))    // implement find I/O burst error
                return error.ioerror
            else    
                try allocator.dupe(u8, tok1),
            .at = std.fmt.parseInt(u8, tok2, 10) catch return error.UnableToParseArrival,
            .bt = std.fmt.parseInt(u8, tok3, 10) catch return error.UnableToParseBurst,
            .tt = std.fmt.parseInt(u8, tok3, 10) catch return error.UnableToParseTurnaround,
        };

        try processes.append(p);
    }

    for (processes.items) |p| {
        std.debug.print("pid: {s}, at: {d}, bt: {d}, tt: {d}\n", .{ p.pid, p.at, p.bt, p.tt });
    }
}


// FCFS (without I/O burst handling)
pb fn FF(processes) !void {
    var sum: u8 = 0;
    var x: u8 = 0;
    std.sort.sort(Data, processes.items, {}, cmpByData);
    
    for (processes.items) |p| {  
        x = p.bt;
        var ans = sum - p.at;      // need to append to struct member (currently just prints)
        sum += p.bt;
        std.debug.print("p.tt: {d}\n", .{ans});
    }
    sum -= x;
    var avg = sum/processes.items.len;
    std.debug.print("avg: {d}\n", .{avg});
}



// 64kb page or else return out of memory
// when cycle == at, pid -> ready.
// in blue queue, wait time increase
// bt -= when in i/o wait queue
// cpu, service item decrease
// in wait queue, if bt == 0, pid -> ready.
// when cpu == 0, service one more time and moved to finish