const std = @import("std");

var NUM_THREADS: usize = undefined;
// var remainingBytes_Lock: std.Io.Mutex = .init;
// var remainingBytes: usize = undefined;
var BLOCK_SIZE: usize = undefined;
const MAX_LINE_LENGTH: usize= 32;

pub fn main(init: std.process.Init) !void {
    var args = init.minimal.args.iterate();
    defer args.deinit();
    _ = args.skip();

    NUM_THREADS = try std.Thread.getCpuCount();

    const fileName = args.next().?;
    const fileHandle = try std.Io.Dir.cwd().openFile(init.io, fileName, .{ .mode = .read_only });
    defer fileHandle.close(init.io);

    const fileStat = try fileHandle.stat(init.io);
    BLOCK_SIZE = fileStat.block_size;
    // remainingBytes = fileStat.size;
    // remainingBytes_Lock.unlock(init.io);


    // for (1..NUM_THREADS) |tid| {
    //     const thread_handle = try std.Thread.spawn(.{}, task, .{ fileName, tid, init });
    //     thread_handle.join();
    // }
    const offset = 0;
    const lengthToLoad = fileStat.size;
    try task(init, fileHandle,lengthToLoad, offset);
}

fn task(init: std.process.Init, fileHandle: std.Io.File, lengthToLoad:usize, offset: usize) !void {
// fn task(fileName: [:0]const u8, threadId: usize, init: std.process.Init) !void {
    // _ = threadId;
    // const fileHandle = try std.Io.Dir.cwd().openFile(init.io, fileName, .{});
    // defer fileHandle.close(init.io);
    // var rwBuf: [4096]u8 = undefined;
    // var fileReader = fileHandle.reader(init.io, &rwBuf);

    var mmap = try fileHandle.createMemoryMap(init.io, .{.len = lengthToLoad,.offset = offset,.protection = .{.write = false,.read = true,.execute = false}});
    defer @constCast(&mmap).destroy(init.io);
    try mmap.read(init.io);
    var count: usize = 0;
    const start_time = std.Io.Clock.awake.now(init.io);
    var reader = std.Io.Reader.fixed(mmap.memory);


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

    var rwBuf: [64] u8 = undefined;
    while (true) {
        const line = reader.takeDelimiterInclusive('\n') catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };
        count += line.len;
        // std.debug.print("line:{s}", .{line});
        const index = std.mem.find(u8, line, ";").?;
        const temp = try std.fmt.parseFloat(f16, line[index + 1 ..line.len-1]);
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
    mmap.destroy(init.io);
    const outFileHandle = try std.Io.Dir.cwd().createFile(init.io, try std.fmt.allocPrint(keyAllocator, "{s}_out.txt", .{"hmm"}), .{});
    defer outFileHandle.close(init.io);
    var outFileReader = outFileHandle.writer(init.io, &rwBuf);
    var iter = cityMap.iterator();

    while (iter.next()) |entry| {
        try outFileReader.interface.print("{s}={d:.1}/{d:.1}/{d:.1},", .{ entry.key_ptr.*, entry.value_ptr.minTemp, entry.value_ptr.meanTemp, entry.value_ptr.maxTemp });
    }
    try outFileReader.interface.flush();

    const elapsed = start_time.untilNow(init.io, .awake);
    _ = elapsed; // autofix
    // std.debug.print("Elapsed time: {} us\n", .{elapsed.toMicroseconds()});
    // std.debug.print("final bytecount:{d}\n", .{count});
}

inline fn F16(int: anytype) f16 {
    return @floatFromInt(int);
}

// test
