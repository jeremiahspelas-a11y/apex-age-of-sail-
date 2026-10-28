"""Run one real WebSocket Godot host and two clients with bounded lifetimes."""
import argparse
import pathlib
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser()
parser.add_argument("godot")
args = parser.parse_args()
project = pathlib.Path(__file__).resolve().parents[1]
roles = ("server", "helm", "rig")
with tempfile.TemporaryDirectory(prefix="apex-coop-") as directory:
    processes = []
    streams = []
    try:
        for role in roles:
            stream = open(pathlib.Path(directory) / (role + ".log"), "w+")
            streams.append(stream)
            processes.append(subprocess.Popen([
                args.godot, "--headless", "--path", str(project),
                "--script", "res://tests/coop_peer_test.gd", "--", "--role=" + role,
            ], stdout=stream, stderr=subprocess.STDOUT))
            time.sleep(0.5)
        deadline = time.monotonic() + 30
        for process in processes:
            process.wait(timeout=max(1, deadline - time.monotonic()))
        passed = True
        for role, process, stream in zip(roles, processes, streams):
            stream.seek(0)
            log = stream.read()
            expected = "APEX COOP PEER PASS: " + role
            ok = process.returncode == 0 and expected in log and "SCRIPT ERROR" not in log and "ERROR:" not in log
            passed &= ok
            print(role + ": " + ("PASS" if ok else "FAIL"))
            if not ok:
                print(log)
        if not passed:
            raise SystemExit(1)
        print("APEX COOP TEST PASS: host and two WebSocket clients, shared ship/weather, station ownership and disconnect cleanup")
    finally:
        for process in processes:
            if process.poll() is None:
                process.kill()
                process.wait()
        for stream in streams:
            stream.close()
