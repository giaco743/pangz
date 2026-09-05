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
   Captured Bytes:   0 bytes
   Original Bytes:   0 bytes
   Duration:         0 ms

 Performance & Throughput:
   Packets / Sec:    0 pps
   Avg Packet Size:  985 bytes
   Throughput:       0 bps (0.00 Mbps)

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
  Time (mean ± σ):     222.7 ms ±   1.3 ms    [User: 78.0 ms, System: 144.1 ms]
  Range (min … max):   219.6 ms … 224.5 ms    13 runs
 
Benchmark 2: capinfos -c testfiles/large.pcapng
  Time (mean ± σ):     734.9 ms ±   6.1 ms    [User: 553.2 ms, System: 180.0 ms]
  Range (min … max):   723.2 ms … 742.6 ms    10 runs
 
Summary
  ./pangz testfiles/large.pcapng > /dev/null ran
    3.30 ± 0.03 times faster than capinfos -c testfiles/large.pcapng
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
