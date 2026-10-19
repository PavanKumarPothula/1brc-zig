# 1BRC-zig

This is based on the challenge here: https://github.com/gunnarmorling/1brc/.

> The One Billion Row Challenge (1BRC) is a fun exploration of how far modern Java can be pushed for aggregating one billion rows from a text file. 
> Grab all your (virtual) threads, reach out to SIMD, optimize your GC, or pull any other trick, and create the fastest implementation for solving this task!

I decided to implement this in Zig as a learning experience.

# TODOs
1. MultiThreading.
2. Floating point math optimizations.
3. SIMD.
4. MMAP.

# Plan and Progress
## Rev-0 [DONE]
It is taking 20min! with the crudest version.
### Arch
1. Read inputFile line by line.
2. Add to the hashmap if new, else compute the new values and update the map.
3. Once done, write the value to outfile one by one.

## Rev-1 [WIP]
This is taking 
- 32ms for mini_measurements.
### Arch
1. Read input from mmap of the file.
2. Add to the hashmap if new, else compute the new values and update the map.
3. Once done, write to out file one by one instead of using mmap. (This will change in the next rev)


## Rev-1
We'll use the multithreading for this:
### Arch
1. N workers will be spawned to read equally divided sections of the inputFile.
2. Each worker will compute and build their own hashmaps for their sections.
3. A seperate function will be reserved to merge all the maps into a final one.
4. Once all are done, write to outFile in the main thread.
