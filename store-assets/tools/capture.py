"""Boot a simulator, clean the status bar, run the store capture harness and
screenshot the simulator whenever the harness prints CAPTURE:<name>.

usage: python3 capture.py <udid> <out_dir> [screens|video]
In video mode it records the whole run to <out_dir>/raw.mov instead.
"""
import subprocess, sys, pathlib, signal, time

udid, out = sys.argv[1], pathlib.Path(sys.argv[2])
mode = sys.argv[3] if len(sys.argv) > 3 else "screens"
out.mkdir(parents=True, exist_ok=True)
REPO = str(pathlib.Path(__file__).resolve().parents[2])

subprocess.run(["xcrun", "simctl", "boot", udid], capture_output=True)
subprocess.run(["xcrun", "simctl", "bootstatus", udid, "-b"], check=True, capture_output=True)
subprocess.run(["xcrun", "simctl", "ui", udid, "appearance", "dark"], capture_output=True)
subprocess.run(["xcrun", "simctl", "status_bar", udid, "override", "--time", "9:41",
                "--dataNetwork", "wifi", "--wifiMode", "active", "--wifiBars", "3",
                "--cellularMode", "active", "--cellularBars", "4",
                "--batteryState", "charged", "--batteryLevel", "100"], check=True)

recorder = None
proc = subprocess.Popen(
    ["flutter", "test", "integration_test/store_capture_test.dart", "-d", udid,
     f"--dart-define=CAPTURE_MODE={mode}"],
    cwd=REPO, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)

shots = []
for line in proc.stdout:
    sys.stdout.write(line)
    if mode == "video" and recorder is None and "store capture" in line:
        recorder = subprocess.Popen(["xcrun", "simctl", "io", udid, "recordVideo", "--codec=h264",
                                     "--force", str(out / "raw.mov")])
        t0 = time.time()
    if mode == "video" and "SCENE:" in line and recorder is not None:
        with open(out / "scenes.txt", "a") as f:
            f.write(f"{time.time() - t0:.2f} {line.split('SCENE:', 1)[1].strip()}\n")
    if "CAPTURE:" in line and mode == "screens":
        name = line.split("CAPTURE:", 1)[1].strip()
        path = out / f"{name}.png"
        subprocess.run(["xcrun", "simctl", "io", udid, "screenshot", str(path)], check=True, capture_output=True)
        shots.append(path.name)
        print(f">>> saved {path.name}", flush=True)
proc.wait()
if recorder:
    time.sleep(1)
    recorder.send_signal(signal.SIGINT)
    recorder.wait()
print("exit", proc.returncode, "shots", shots)
