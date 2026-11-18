#!/usr/bin/env python3
"""How steady is a Google Cast speaker's clock? The first question for a Home.io bridge that would line Google
speakers up with AirPlay 2 ones.

Plays a quiet tone to one Cast speaker, MUTED, and asks it every 2 seconds where in the tone it is. Against this
Mac's clock that gives: how long the speaker takes to start, how fast its clock runs compared with ours (drift), and
how much its answers wander (jitter). It does not hear the speaker: the delay between "position" and sound coming
out needs a microphone, a later test.

    python3 cast_timing.py "Kitchen Display" 8        # name as the Google Home app shows it, minutes

The speaker's mute is put back as it was, and the tone is stopped, also when the run is interrupted.
Needs: pip install pychromecast
"""
import http.server, json, math, os, socket, struct, sys, tempfile, threading, time, wave

import pychromecast

name = sys.argv[1]
minutes = float(sys.argv[2]) if len(sys.argv) > 2 else 8
out = sys.argv[3] if len(sys.argv) > 3 else "cast_timing.json"

# the tone: 2 minutes longer than the run, 22.05 kHz mono
rate = 22050
folder = tempfile.mkdtemp()
path = os.path.join(folder, "tone.wav")
with wave.open(path, "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
    second = b"".join(struct.pack("<h", int(600 * math.sin(2 * math.pi * 220 * i / rate))) for i in range(rate))
    for _ in range(int((minutes + 2) * 60)):
        w.writeframes(second)

casts, browser = pychromecast.get_listed_chromecasts(friendly_names=[name], timeout=15)
if not casts:
    sys.exit(f"no Cast speaker named {name!r} on this network")
cast = casts[0]
cast.wait(timeout=20)
host = cast.cast_info.host

# this Mac's address as the speaker sees it
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.connect((host, 8009)); mine = s.getsockname()[0]; s.close()
handler = lambda *a, **k: http.server.SimpleHTTPRequestHandler(*a, directory=folder, **k)
server = http.server.ThreadingHTTPServer((mine, 0), handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
url = f"http://{mine}:{server.server_address[1]}/tone.wav"

was_muted = cast.status.volume_muted
samples = []
try:
    cast.set_volume_muted(True)
    time.sleep(1)
    mc = cast.media_controller
    asked = time.time()
    mc.play_media(url, "audio/wav")
    mc.block_until_active(timeout=30)
    while mc.status.player_state != "PLAYING":
        if time.time() - asked > 60:
            sys.exit(f"the speaker never started playing (state {mc.status.player_state})")
        time.sleep(0.1)
    started = time.time()
    print(f"started {started - asked:.2f} s after asking", flush=True)
    end = started + minutes * 60
    while time.time() < end:
        before = time.time()
        mc.update_status()
        time.sleep(0.5)                       # (the answer arrives on the listener thread)
        st = mc.status
        if st.player_state == "PLAYING" and st.last_updated:
            at = st.last_updated.timestamp()  # when the answer came in, by this Mac's clock
            samples.append((at, st.current_time))
        time.sleep(max(0, 2 - (time.time() - before)))
    mc.stop()
finally:
    try:
        cast.quit_app()
        cast.set_volume_muted(was_muted)
        time.sleep(1)
    finally:
        browser.stop_discovery()
        server.shutdown()

# position against our clock: a straight line. Its slope is the speaker's clock speed, what's left over is jitter.
t0 = samples[0][0]
xs = [a - t0 for a, _ in samples]; ys = [p for _, p in samples]
n = len(xs); mx = sum(xs) / n; my = sum(ys) / n
slope = sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / sum((x - mx) ** 2 for x in xs)
left = [y - (my + slope * (x - mx)) for x, y in zip(xs, ys)]
rms = math.sqrt(sum(r * r for r in left) / n)
result = {
    "speaker": name, "model": cast.cast_info.model_name, "minutes": minutes, "answers": n,
    "start_delay_s": round(started - asked, 3),
    "drift_ppm": round((slope - 1) * 1e6, 1),
    "drift_ms_per_hour": round((slope - 1) * 3600e3, 1),
    "jitter_rms_ms": round(rms * 1000, 1),
    "jitter_worst_ms": round(max(abs(r) for r in left) * 1000, 1),
    "residuals_ms": [round(r * 1000, 1) for r in left],
}
json.dump(result, open(out, "w"), indent=1)
print({k: v for k, v in result.items() if k != "residuals_ms"})
