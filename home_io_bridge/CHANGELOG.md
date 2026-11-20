# Changelog

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
