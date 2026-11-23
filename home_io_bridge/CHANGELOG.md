# Changelog

## 0.2.3

A speaker no longer drops out of the AirPlay list when it stops answering for a moment. Checked by the engine's
tests; not yet seen on real speakers before this version was made.

- A speaker that stops answering (a restart, a moment off Wi-Fi) stays in the AirPlay list for 5 minutes while the
  add-on keeps reconnecting. Before, it was taken out of the list a few seconds after it stopped answering.
- A speaker that was taken out is tried again at its last address every 30 seconds, and is back in the AirPlay list
  as soon as it answers (the log says "departed Chromecast answers again; back in AirPlay"). Before, it came back
  only when it next announced itself on the network, which took over half an hour.

## 0.2.2

Reliability. Checked by the engine's tests; the changes to speakers' behavior were not heard on real speakers
before this version was made.

- A speaker's standby connection that the speaker had closed was never noticed and stayed in use. It is now
  replaced at once (the log says "Cast control connection closed by the speaker; reconnecting"). Before, the
  first start after it came a moment late, and a pause from the phone during playback could be lost.
- A start that fails on the speaker's side is tried again, up to two more times. If it still fails, the AirPlay
  session is ended, so the phone shows the speaker dropped instead of playing into silence.
- A pause or play that fails is sent once more on a new connection.
- A speaker kept in time no longer ends up out of time until the add-on is restarted: a slow start is tried
  again instead of switching to the fallback stream, the fallback is forgotten after 30 minutes, the three
  corrections of a session come back after five minutes in time, and a speaker the engine had to reload on its
  own is started again right away instead of sitting silent for about 7 seconds.
- A speaker waits up to 10 seconds for a start, not 6.
- From PlayOnAir: a quiet intro or a long silence no longer stalls the speaker; after a skip the speaker no longer
  plays half a second and then buffers for about 10 seconds; the speaker stops when the phone stops, instead
  of playing on for about 12 seconds.
- The log says what a speaker reported when a pause or play on the speaker is passed on to the phone.

## 0.2.1

- Says when a speaker can't be kept in time: after three tries and a minute still off, the log says so and Home.io
  shows "Out of time right now" under the speaker until it is back.

## 0.2.0

First public version, as a fork of PlayOnAir 0.4.0.

- Google speakers are kept in time with AirPlay speakers: Nest Hub, Nest Mini and Nest Audio.
- Each speaker model's start is learned, and begins from a built-in value.
- A speaker far out of time is stepped back instead of sped up or slowed down for a long while.
- Speakers kept in time each get their own stream; they are no longer put in a Google speaker group.
- Volume works on a Nest Hub.
- Home.io can move a speaker model a few milliseconds earlier or later.
- The log is also kept as `engine.log` in the add-on's configuration folder, with timing detail.
