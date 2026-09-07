import re
from dataclasses import dataclass
import subprocess
from pathlib import Path
import sys
import math



@dataclass
class PcapngStatistics:
    file_size: int
    total_packets: int
    captured_bytes: int
    duration: float
    packets_per_sec: float
    avg_packet_size: float
    throughput_bps: float
    interfaces: int
    
    def __eq__(self, other: object) -> bool:
        if not isinstance(other, PcapngStatistics):
            return NotImplemented

        return (
            self.file_size == other.file_size
            and self.total_packets == other.total_packets
            and self.captured_bytes == other.captured_bytes
            and math.isclose(self.duration, other.duration, abs_tol=1e-2)
            and math.isclose(self.packets_per_sec, other.packets_per_sec, abs_tol=1.0)
            and math.isclose(self.avg_packet_size, other.avg_packet_size, abs_tol=0.01)
            and math.isclose(self.throughput_bps, other.throughput_bps, abs_tol=1.0)
            and self.interfaces == other.interfaces
        )
    def differences(self, other: "PcapngStatistics") -> dict:
        differences = {}
        
        # 1. Check exact-match integer fields
        int_fields = ["file_size", "total_packets", "captured_bytes", "interfaces"]
        for field in int_fields:
            self_val = getattr(self, field)
            other_val = getattr(other, field)
            if self_val != other_val:
                differences[field] = (self_val, other_val)

        # 2. Check floating-point fields using the identical 'isclose' tolerances
        float_tolerances = {
            "duration": 1e-2,
            "packets_per_sec": 1.0,
            "avg_packet_size": 0.01,
            "throughput_bps": 1.0,
        }
        
        for field, tol in float_tolerances.items():
            self_val = getattr(self, field)
            other_val = getattr(other, field)
            if not math.isclose(self_val, other_val, abs_tol=tol):
                differences[field] = (self_val, other_val)

        return differences

def parse_pangz_output(output: str) -> PcapngStatistics:
    patterns = {
        "file_size": r"File Size:\s+(\d+)\s+bytes",

        "total_packets": r"Total Packets:\s+(\d+)",
        "captured_bytes": r"Captured Bytes:\s+(\d+)\s+bytes",
        "duration": r"Duration:\s+([\d.eE+-]+|inf|-inf)\s+s",

        "packets_per_sec": r"Packets / Sec:\s+([\d.eE+-]+|inf|-inf)\s+pps",
        "avg_packet_size": r"Avg Packet Size:\s+([\d.eE+-]+|inf|-inf)\s+bytes",
        "throughput_bps": r"Throughput:\s+([\d.eE+-]+|inf|-inf)\s+bps",

        "interfaces": r"Interfaces:\s+(\d+)",
    }

    values = {}

    for key, pattern in patterns.items():
        match = re.search(pattern, output)

        if not match:
            raise ValueError(f"Could not find '{key}' in pangz output")


        value = match.group(1)
        if key in {
            "file_size",
            "total_packets",
            "captured_bytes",
            "interfaces",
        }:
            values[key] = int(value)
        else:
            values[key] = float(value)

    return PcapngStatistics(**values)

def parse_capinfos_output(output: str) -> PcapngStatistics:
    def get(pattern: str) -> str:
        match = re.search(pattern, output, re.MULTILINE)
        if not match:
            raise ValueError(f"Could not find field matching: {pattern}")
        return match.group(1)

    def get_int(pattern: str) -> int:
        # "." is used as thousands separator
        return int(get(pattern).replace(".", ""))

    def get_float(pattern: str) -> float:
        # "," is the decimal separator
        return float(get(pattern).replace(".", "").replace(",", "."))

    def get_size(pattern: str) -> int:
        match = re.search(pattern, output, re.MULTILINE)
        if not match:
            raise ValueError(f"Could not find size matching: {pattern}")

        # "." = thousands separator
        # "," = decimal separator
        value = match.group(1).replace(".", "").replace(",", ".")
        value = float(value)

        unit = match.group(2)

        multipliers = {
            "bytes": 1,
            "kB": 1000,
            "MB": 1000**2,
            "GB": 1000**3,
            "TB": 1000**4,
        }

        return int(value * multipliers[unit])

    def get_throughput(pattern: str) -> int:
        match = re.search(pattern, output, re.MULTILINE)
        if not match:
            raise ValueError(f"Could not find throughput matching: {pattern}")

        # "." = thousands separator
        # "," = decimal separator
        value = match.group(1).replace(".", "").replace(",", ".")
        value = float(value)

        unit = match.group(2)

        multipliers = {
            "bits/s": 1,
            "kbps": 1000,
            "Mbps": 1000**2,
            "Gbps": 1000**3,
            "Tbps": 1000**4,
        }

        return int(value * multipliers[unit])

    def get_packet_throughput(pattern: str) -> int:
        match = re.search(pattern, output, re.MULTILINE)
        if not match:
            raise ValueError(f"Could not find packet throughput matching: {pattern}")

        # "." = thousands separator
        # "," = decimal separator
        value = match.group(1).replace(".", "")
        value = int(value)

        unit = match.group(2)

        multipliers = {
            "packets/s": 1,
            "kpackets/s": 1000,
            "Mpackets/s": 1000**2,
            "Gpackets/s": 1000**3,
            "Tpackets/s": 1000**4,
        }
        return int(value * multipliers[unit])
        
    def get_packets(pattern: str) -> int:
        match = re.search(pattern, output, re.MULTILINE)
        if not match:
            raise ValueError(f"Could not find packets matching: {pattern}")

        # "." = thousands separator
        # "," = decimal separator
        value = match.group(1).replace(".", "").replace(",", ".")
        value = float(value)

        unit = match.group(2)

        multipliers = {
            None: 1,
            "k": 1000,
            "M": 1000**2,
            "G": 1000**3,
            "T": 1000**4,
        }

        return int(value * multipliers[unit])

    return PcapngStatistics(
        file_size=get_size(
            r"^\s*File size:\s*([\d.,]+)\s+(bytes|kB|MB|GB|TB)"
        ),

        total_packets=get_packets(
            r"^\s*Number of packets:\s*([\d.]+)(?:\s+(k|M))?"
        ),

        captured_bytes=get_size(
            r"^\s*Data size:\s*([\d.,]+)\s*(bytes|kB|MB|GB|TB)"
        ),

        duration=get_float(
            r"^\s*Capture duration:\s*([\d.,]+)\s+seconds"
        ),

        packets_per_sec=get_packet_throughput(
            r"^\s*Average packet rate:\s*([\d.,]+)\s+(packets/s|kpackets/s|Mpackets/s)"
        ),

        avg_packet_size=get_float(
            r"^\s*Average packet size:\s*([\d.,]+)\s+bytes"
        ),

        throughput_bps=get_throughput(
            r"^\s*Data bit rate:\s*([\d.,]+)\s+(bits/s|kbps|Mbps)"
        ),

        interfaces=get_int(
            r"^\s*Number of interfaces in file:\s+([\d.]+)"
        ),
    )


if __name__ == "__main__":
    directory_path = Path(sys.argv[1])

    results = {}

    for pcapng_file in sorted(directory_path.glob("*.pcapng")):
        print(f"Processing {pcapng_file}...")

        try:
            capinfos_result = subprocess.run(
                ["capinfos", "-A", pcapng_file],
                capture_output=True,
                text=True,
                check=True,
            )
            # print(f"Stdout: {capinfos_result.stdout}")
            capinfos = parse_capinfos_output(capinfos_result.stdout)
            # print(f"Parsed: {capinfos}")
            
            
            pangz_result = subprocess.run(
                ["zig", "run", "main.zig", "--", pcapng_file],
                capture_output=True,
                text=True,
                check=True,
            )
            pangz = parse_pangz_output(pangz_result.stdout)
            
            # assert capinfos == pangz, "Pangz output differs from capinfos"
            if capinfos == pangz:
                print("MATCH!!!")
            else:
                print("DO NOT MATCH:")
                for field, (capinfo_value, pangz_value) in capinfos.differences(pangz).items():
                    print(f"  {field}: capinfos={capinfo_value}, pangz={pangz_value}")
        except (RuntimeError, ValueError) as e:
            print(f"  ERROR: {e}")