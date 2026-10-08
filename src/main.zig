const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const fileName = "mini_measurements.txt";
    const fileHandle = try std.Io.Dir.cwd().openFile(init.io, fileName, .{});
    defer fileHandle.close(init.io);

    var readBuf: [4096]u8 = undefined;
    var fileReader = fileHandle.reader(init.io, &readBuf);

    const TempStats = struct { numRecords: u128, meanTemp: f16, minTemp: f16, maxTemp: f16 };
    const hashMapType = std.StringHashMap(TempStats);
    const childAlloc = std.heap.page_allocator;
    // const mainAlloc = std.heap.ArenaAllocator;

    // var cityList: std.ArrayList([]u8) = .empty;
    // defer cityList.deinit(init.gpa);
    // var minTemp: hashMap = .init(childAlloc);
    // defer minTemp.deinit();
    // var maxTemp: hashMap = .init(childAlloc);
    // defer maxTemp.deinit();
    // var meanTemp: hashMap = .init(childAlloc);
    // defer meanTemp.deinit();

    var cityMap: hashMapType = .init(childAlloc);

    while (try fileReader.interface.takeDelimiter('\n')) |line| {
        const index = std.mem.find(u8, line, ";").?;
        const cityName = line[0..index];
        const temp = try std.fmt.parseFloat(f16, line[index + 1 ..]);

        if (cityMap.get(cityName)) |currentData| {
            try cityMap.put(cityName, .{
                .numRecords = currentData.numRecords + 1,
                .meanTemp = ((1 / 1 + (1 / F16(currentData.numRecords))) * (currentData.meanTemp)) + (temp / F16(currentData.numRecords + 1)),
                .minTemp = @min(temp, currentData.minTemp),
                .maxTemp = @max(temp, currentData.maxTemp),
            });
        } else {
            try cityMap.put(cityName, .{
                .numRecords = 1,
                .meanTemp = temp,
                .maxTemp = temp,
                .minTemp = temp,
            });
        }
    }
    var iter = cityMap.iterator();
    while (iter.next()) |entry| {
        std.debug.print("{s} :: {} \n", .{ entry.key_ptr.*, entry.value_ptr.*.numRecords });
    }
}

inline fn F16(int: anytype) f16 {
    return @floatFromInt(int);
}
