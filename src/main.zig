const std = @import("std");

const NUM_THREADS = 12;

pub fn main(init: std.process.Init) !void {
    var args = init.minimal.args.iterate();
    defer args.deinit();
    _ = args.skip();

    const fileName = args.next().?;
    const fileHandle = try std.Io.Dir.cwd().openFile(init.io, fileName, .{});
    defer fileHandle.close(init.io);
    var rwBuf: [256]u8 = undefined;
    var fileReader = fileHandle.reader(init.io, &rwBuf);

    var count: usize = 0;
    const start_time = std.Io.Clock.awake.now(init.io);
    while (true) {
        const line = fileReader.interface.takeDelimiterInclusive('\n') catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };
        // std.debug.print("line:{s}::bytes:{d}\n", .{ line, line.len });
        count += line.len;
    }

    const elapsed = start_time.untilNow(init.io, .awake);
    std.debug.print("Elapsed time: {} s\n", .{elapsed.toSeconds()});
    std.debug.print("final bytecount:{d}\n", .{count});
    // for (1..NUM_THREADS) |tid| {
    //     const thread_handle = try std.Thread.spawn(.{}, task, .{ fileName, tid, init });
    //     thread_handle.join();
    // }
}

fn task(fileName: [:0]const u8, threadId: usize, init: std.process.Init) !void {
    _ = threadId;
    const fileHandle = try std.Io.Dir.cwd().openFile(init.io, fileName, .{});
    defer fileHandle.close(init.io);
    var rwBuf: [4096]u8 = undefined;
    var fileReader = fileHandle.reader(init.io, &rwBuf);

    const TempStats = struct { numRecords: u128, meanTemp: f16, minTemp: f16, maxTemp: f16 };
    const hashMapType = std.StringHashMap(TempStats);

    var areana: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer areana.deinit();
    const mapAllocator = areana.allocator();

    var cityMap: hashMapType = .init(mapAllocator);

    defer {
        var key_iter = cityMap.keyIterator();
        while (key_iter.next()) |key| {
            mapAllocator.free(key.*);
        }
        cityMap.deinit();
    }

    const keyAllocator = mapAllocator;
    while (try fileReader.interface.takeDelimiter('\n')) |line| {
        const index = std.mem.find(u8, line, ";").?;
        const temp = try std.fmt.parseFloat(f16, line[index + 1 ..]);
        const query = try cityMap.getOrPut(line[0..index]);

        if (query.found_existing) {
            // const currentData = query.value_ptr;
            // const oldCityName = query.key_ptr;
            // std.debug.print("{s}\n", .{oldCityName.*});
            // std.debug.print("{d}::{d}::{d} + {d}\n", .{ query.value_ptr.minTemp, query.value_ptr.meanTemp, query.value_ptr.maxTemp, temp });
            query.value_ptr.meanTemp =
                (query.value_ptr.meanTemp / (1 + (1 / F16(query.value_ptr.numRecords)))) + (temp / F16(query.value_ptr.numRecords + 1));
            query.value_ptr.numRecords = query.value_ptr.numRecords + 1;
            query.value_ptr.minTemp = @min(temp, query.value_ptr.minTemp);
            query.value_ptr.maxTemp = @max(temp, query.value_ptr.maxTemp);

            // std.debug.print("{d}::{d}::{d}\n", .{ query.value_ptr.minTemp, query.value_ptr.meanTemp, query.value_ptr.maxTemp });
        } else {
            query.key_ptr.* = try keyAllocator.dupe(u8, line[0..index]);
            // std.debug.print("{d}:::{d}:::{s}\n", .{ cityMap.capacity(), cityMap.count(), query.key_ptr.* });
            query.value_ptr.numRecords = 1;
            query.value_ptr.meanTemp = temp;
            query.value_ptr.maxTemp = temp;
            query.value_ptr.minTemp = temp;
            // std.debug.print("{d}::{d}::{d}\n", .{ query.value_ptr.minTemp, query.value_ptr.meanTemp, query.value_ptr.maxTemp });
        }
    }
    const outFileHandle = try std.Io.Dir.cwd().createFile(init.io, try std.fmt.allocPrint(keyAllocator, "{s}_out.txt", .{"hmm"}), .{ .exclusive = true });
    defer outFileHandle.close(init.io);
    var outFileReader = outFileHandle.writer(init.io, &rwBuf);
    var iter = cityMap.iterator();

    while (iter.next()) |entry| {
        try outFileReader.interface.print("{s}={d:.1}/{d:.1}/{d:.1},", .{ entry.key_ptr.*, entry.value_ptr.minTemp, entry.value_ptr.meanTemp, entry.value_ptr.maxTemp });
    }
    try outFileReader.interface.flush();
}

inline fn F16(int: anytype) f16 {
    return @floatFromInt(int);
}
