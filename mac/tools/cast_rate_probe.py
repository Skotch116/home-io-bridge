#!/usr/bin/env python3
"""Does a Cast speaker let us nudge its playback? Plays a MUTED tone, then tries the two controls a sync loop could
use and watches the reported position: a faster playback rate for 20 s, and a short seek forward.

    python3 cast_rate_probe.py "Kitchen Display"

Mute is put back and the tone stopped at the end. Needs: pip install pychromecast
"""
import http.server, math, os, socket, struct, sys, tempfile, threading, time, wave
import pychromecast

name = sys.argv[1]
rate = 22050
folder = tempfile.mkdtemp()
with wave.open(os.path.join(folder, "tone.wav"), "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
    second = b"".join(struct.pack("<h", int(600 * math.sin(2 * math.pi * 220 * i / rate))) for i in range(rate))
    for _ in range(240): w.writeframes(second)

casts, browser = pychromecast.get_listed_chromecasts(friendly_names=[name], timeout=15)
if not casts: sys.exit(f"no Cast speaker named {name!r}")
cast = casts[0]; cast.wait(timeout=20)
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.connect((cast.cast_info.host, 8009)); mine = s.getsockname()[0]; s.close()
server = http.server.ThreadingHTTPServer((mine, 0), lambda *a, **k: http.server.SimpleHTTPRequestHandler(*a, directory=folder, **k))
threading.Thread(target=server.serve_forever, daemon=True).start()
mc = cast.media_controller
was_muted = cast.status.volume_muted

def position():
    mc.update_status(); time.sleep(0.6)
    return mc.status.last_updated.timestamp(), mc.status.current_time

def slope(seconds):
    a = position(); time.sleep(seconds); b = position()
    return (b[1] - a[1]) / (b[0] - a[0])

try:
    cast.set_volume_muted(True); time.sleep(1)
    mc.play_media(f"http://{mine}:{server.server_address[1]}/tone.wav", "audio/wav")
    mc.block_until_active(timeout=30)
    t = time.time()
    while mc.status.player_state != "PLAYING":
        if time.time() - t > 60: sys.exit("never started")
        time.sleep(0.1)
    time.sleep(5)
    print("supported_media_commands", mc.status.supported_media_commands, "rate reported", mc.status.playback_rate, flush=True)
    print("speed at rate 1.00:", round(slope(15), 4), flush=True)
    mc.set_playback_rate(1.05); time.sleep(1)
    print("speed asked 1.05:", round(slope(15), 4), "rate reported", mc.status.playback_rate, flush=True)
    mc.set_playback_rate(0.95); time.sleep(1)
    print("speed asked 0.95:", round(slope(15), 4), "rate reported", mc.status.playback_rate, flush=True)
    mc.set_playback_rate(1.0); time.sleep(1)
    a = position(); mc.seek(a[1] + (time.time() - a[0]) + 2.0); time.sleep(2); b = position()
    print("seek +2 s: position moved", round((b[1] - a[1]) - (b[0] - a[0]), 3), "s beyond the clock; state", mc.status.player_state, flush=True)
    mc.stop()
finally:
    try:
        cast.quit_app(); cast.set_volume_muted(was_muted); time.sleep(1)
    finally:
        browser.stop_discovery(); server.shutdown()
