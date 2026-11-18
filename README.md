# Home.io Bridge

Makes the Google Cast speakers on your network (Nest Hub, Nest Mini, Nest Audio) show up as AirPlay 2 speakers on
every iPhone, iPad and Mac in the house, and keeps them **in time** with your real AirPlay speakers, so a Nest Hub in
the kitchen and a HomePod in the pantry can play the same song together.

It runs as a Home Assistant add-on, or inside a small Mac menu bar app. It is free and open source, and it is
experimental: it has been heard working in one home.

## What is different about it

Other bridges make a Google speaker appear in the AirPlay list, but it then plays a moment behind your AirPlay
speakers, so a mixed group echoes. This one is built to stay in step:

- **It plays each Google speaker on the sender's clock.** The music an iPhone sends carries the moment each part is
  due. The bridge starts the Google speaker early by that speaker's own delay, then checks once a second where the
  speaker really is and nudges it, a few samples at a time, to stay on that moment.
- **It learns each speaker model's start.** Where a start lands is measured, and the next start is sent that much
  earlier or later, so it begins in step instead of drifting into it.
- **Each Google speaker gets its own timed stream.** Two Google speakers are not handed to a Google speaker group,
  which runs on Google's clock and plays a second or two apart from AirPlay speakers.
- **Volume works on a Nest Hub.** A Nest Hub takes Cast's volume and reports it back without getting louder or
  quieter; the bridge sets the stream's own volume there, so the iPhone's slider does something.
- **A fine adjustment from your phone.** [Home.io](https://skotch116.github.io/homeio-site/) finds the bridge on your
  network and can move a speaker model a few milliseconds earlier or later (Music, "Google Speakers with AirPlay").
  The bridge works without Home.io.

## What it can't do yet

- Only **Nest Hub, Nest Mini and Nest Audio** are kept in time. Any other Cast device plays, but with no timing.
  (Nest Audio uses the numbers of the engine this is built on; it has not been tried here.)
- The timing numbers come from one home: a Nest Hub and a Nest Mini, with ecobee and HomePod speakers.
  Your speakers may land a little differently; the first seconds of the first play are where you would hear it.
- Sound only. A Chromecast or a TV is not a target.
- You play from an Apple device. Nothing changes for casting from Android or Google Home.

## Install on Home Assistant

1. In Home Assistant: Settings › Apps › Install app › ⋮ › Repositories, and add
   `https://github.com/Skotch116/home-io-bridge`.
2. Find **Home.io Bridge** in the store, install it and start it. It arrives ready-built.
3. Open the AirPlay list on an iPhone: your Google speakers are in it.

The add-on needs the host network (AirPlay and Cast speakers are found by multicast), which its settings already ask
for. Run one bridge per home: two would each offer every speaker.

## On a Mac instead

`mac/tools/make_app.sh install` builds a menu bar app that does the same while the Mac is on (see Build below). Don't
run it together with the add-on.

## How it is built

This repository is a fork of [PlayOnAir](https://github.com/felipefdl/play-on-air) by Felipe Lima, taken from its
0.4.0 release, the version that had its sync work. PlayOnAir's own README is in
[docs/PLAYONAIR-README.md](docs/PLAYONAIR-README.md); `git diff v0.4.0` shows everything changed since.

What the fork adds to the engine: the Nest Hub, the learned start, a step back into time when a speaker is far off
instead of a long audible speed change, no Google groups for timed speakers, stream volume for the Nest Hub, a delay
per speaker model that can be set over the network, and speakers that are no longer dropped from the AirPlay list
while they are still reachable. Around the engine it adds the Mac menu bar app in `mac/` and renames the add-on
(`home_io_bridge/`).

### Build

```bash
cargo test --release -p play-on-air     # the engine's tests
cargo build --release -p play-on-air    # the engine: target/release/play-on-air
mac/tools/make_app.sh                   # mac/build/Home.io Bridge.app (needs the engine built first)
mac/tools/make_app.sh install           # and copy it to /Applications
```

The add-on's image is built by `.github/workflows/docker.yml` from the `Dockerfile` at the top, for Intel and ARM
machines.

`mac/tools/cast_timing.py "<speaker name>" <minutes>` plays a muted tone to one Cast speaker and measures how steady
its clock is (needs `pip install pychromecast`).

## The timing service

The bridge announces `_homeio-bridge._tcp` and answers, with no sign-in, on your home network only:

- `GET /speakers` → `{"speakers":[{"name":"…","model":"Google Nest Hub","delay":0,"synced":true}]}`
- `POST /delay` with `{"model":"Google Nest Hub","delay":40}` (milliseconds, positive plays later, within 500)

A delay is all it can change.

## Reporting a problem

The add-on keeps `engine.log` in its configuration folder, with one line a second while music plays saying how far
the speaker is from where it should be. Open an issue with the speaker's model and the part of that log around
the start of a song. Device ids and network addresses are in it: take out what you don't want public.

## Credits and licenses

- [PlayOnAir](https://github.com/felipefdl/play-on-air) by Felipe Lima, MIT. The sync design this builds on is
  his, and so is most of the code here. If this is useful to you, [he takes
  sponsors](https://github.com/sponsors/felipefdl).
- PlayOnAir carries a fork of the [shairplay](https://github.com/metaneutrons/shairplay-rust) AirPlay 2 receiver
  (`vendor/shairplay`), LGPL-3.0-or-later. Its source is in this repository, and the image is built from this
  repository with the Dockerfile here, so it can be rebuilt with a changed copy of that library.
- The fork's changes are under the same MIT license, in `LICENSE.md`.

Home.io Bridge is not made by, endorsed by or affiliated with Apple or Google. AirPlay, HomePod, iPhone, iPad and
Mac are trademarks of Apple Inc.; Google Cast, Chromecast and Nest are trademarks of Google LLC. It speaks to your
own speakers on your own network; whether to run it is your decision.
