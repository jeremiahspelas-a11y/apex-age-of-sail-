"""Run one real WebSocket Godot host and two clients with bounded lifetimes."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import socket
import pathlib
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser()
parser.add_argument("godot")
args = parser.parse_args()
project = pathlib.Path(__file__).resolve().parents[1]
roles = ("server", "helm", "rig")

def delayed_handshake():
    # Pause an incomplete HTTP upgrade longer than Godot's default 3-second limit.
    with socket.create_connection(("127.0.0.1", 19080), timeout=8) as peer:
        peer.sendall(b"GET / HTTP/1.1\r\nHost: 127.0.0.1:19080\r\n"
                     b"Upgrade: websocket\r\nConnection: Upgrade\r\n"
                     b"Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n"
                     b"Sec-WebSocket-Version: 13\r\n")
        time.sleep(4.2)
        peer.sendall(b"\r\n")
        response = peer.recv(2048)
        if not response.startswith(b"HTTP/1.1 101"):
            raise AssertionError("Delayed WebSocket handshake was dropped: " + repr(response[:80]))

with tempfile.TemporaryDirectory(prefix="apex-coop-") as directory:
    executor = ThreadPoolExecutor(max_workers=1)
    slow_connection = None
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
            if role == "server":
                # Start the slow-upgrade probe only once the actual socket is bound.
                # A fixed 0.5s delay races scene/material initialization on loaded CPUs.
                ready_until = time.monotonic() + 10
                while True:
                    stream.flush()
                    if "Hosting co-op on port 19080" in pathlib.Path(stream.name).read_text():
                        break
                    if processes[-1].poll() is not None or time.monotonic() > ready_until:
                        raise RuntimeError("Co-op server did not become ready: " + pathlib.Path(stream.name).read_text())
                    time.sleep(0.02)
                slow_connection = executor.submit(delayed_handshake)
            else:
                time.sleep(0.5)
        deadline = time.monotonic() + 30
        for process in processes:
            process.wait(timeout=max(1, deadline - time.monotonic()))
        passed = True
        try:
            slow_connection.result(timeout=10)
            print("delayed handshake: PASS (4.2 seconds)")
        except Exception as error:
            passed = False
            print("delayed handshake: FAIL", error)
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
        executor.shutdown(wait=True)
        for stream in streams:
            stream.close()
