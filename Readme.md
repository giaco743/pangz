# `pangz` a fast pcapng analysis tool written in zig

`pangz` is designed for speed by minimizing syscalls and memory copies.

> **Note:** `pangz` is currently a work in progress. It has been tested against example pcapng files, but full compliance with the pcapng specification and comprehensive test coverage are not yet guaranteed. Only basic features are already implemented, alot is still missing.

## Build from source

```
~$ zig build-exe main.zig -O ReleaseFast -femit-bin=pangz
```

## Run

```
./pangz testfiles/large.pcapng 
==================================================
               PCAPNG FILE STATISTICS             
==================================================
 File Size:          1648156248 bytes
 Total Blocks:       1672002 (Sections: 1, Interfaces: 1)

 Capture Metrics:
   Total Packets:    1670000
   Captured Bytes:   1590583000 bytes
   Original Bytes:   1590583000 bytes
   Duration:         8.166391849517822 s

 Performance & Throughput:
   Packets / Sec:    204496.67745230763 pps
   Avg Packet Size:  985 bytes
   Throughput:       194771819.5880981 bps (194.77 Mbps)

 Block Breakdown:
   Enhanced Packets (EPB): 1670000
   Simple Packets (SPB):   0
   Interface Desc (IDB):   1
   Name Resolution (NRB):  1000
   Interface Stats (ISB):  0
   Other Blocks:           1000
==================================================
```

## Benchmark

`pangz` was benchmarked against `capinfos` :

```
$ capinfos -c testfiles/large.pcapng
File name:           testfiles/large.pcapng
Number of packets:   1.670 k
```

The used file is `testfiles/challenge01_ooo_stream.pcapng` repeated 1000 times, which results in a 1, 6G testfile.

```
$ hyperfine --warmup 10 './pangz testfiles/large.pcapng > /dev/null' 'capinfos -c testfiles/large.pcapng'
Benchmark 1: ./pangz testfiles/large.pcapng > /dev/null
  Time (mean ± σ):     281.1 ms ±   3.4 ms    [User: 132.9 ms, System: 147.4 ms]
  Range (min … max):   278.1 ms … 289.2 ms    10 runs
 
Benchmark 2: capinfos -c testfiles/large.pcapng
  Time (mean ± σ):     742.6 ms ±  26.1 ms    [User: 566.4 ms, System: 173.9 ms]
  Range (min … max):   719.5 ms … 811.1 ms    10 runs
 
Summary
  ./pangz testfiles/large.pcapng > /dev/null ran
    2.64 ± 0.10 times faster than capinfos -c testfiles/large.pcapng
```

### Benchmark System

```text
OS: Ubuntu 24.04.3 LTS
Kernel: 6.8.0-138-generic
CPU: Intel(R) Core(TM) i5-7200U CPU @ 2.50GHz
CPU cores: 4
RAM: 7,6Gi
Storage: loop0       4K                           loop
Architecture: x86_64
Zig: 0.16.0
TShark: TShark (Wireshark) 4.2.2 (Git v4.2.2 packaged as 4.2.2-1.1build3).
Capinfos: Capinfos (Wireshark) 4.2.2 (Git v4.2.2 packaged as 4.2.2-1.1build3)
```
