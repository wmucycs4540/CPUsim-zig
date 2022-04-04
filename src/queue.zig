// deque.rotate() function
pub fn rotate(slice, n) {
    for (index) |i| {
        const temp = slice[0];
        std.mem.copy(u8, slice[0..slice.len - 1], slice[1..]);
        slice[slice.len - 1] = temp;
    }
    return slice;
}

// usage (Queue(Proc){}).function()
pub fn Queue(comptime Proc: struct) = type {

    return struct {
    const Self = @This();

        pub fn peek(self: Self) ?u64 {
            return if (self.pid.len > 0) self.pid else null;
        }

        pub fn enque(self: Self, e: u64) {
            self.append(e);
        }

        pub fn deque(self: Self) {
            return if (self.len > 0) self.appendAssumeCapacity(self.orderedRemove(0)) else null;
        }

        pub fn deque_at(self: Self, index: u64) {
            var r = self.len - index - 1;
            rotate(self, index);
            var e = self.deque();
            rotate(self, r);
            return e;
        }
    }
}
