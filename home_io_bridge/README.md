# Home.io Bridge

Makes the Google Cast speakers on your network (Nest Mini, Nest Hub, Nest Audio) show up as AirPlay 2 speakers on
every iPhone, iPad and Mac in the house, and keeps them in time with your other AirPlay speakers.

## Use

1. Install and start the add-on.
2. Open the AirPlay list on an iPhone: your Google speakers are there.
3. If a Google speaker sounds a little ahead of or behind another speaker, open Home.io, Music, and scroll to
   "Google Speakers with AirPlay": Tune by Listening sets it with the phone's microphone, or move it by hand.

## Settings

- **log_level**: how much the add-on writes to its log.
- **device_overrides**: optional. Rename a speaker or hide it from AirPlay. `id` is part of the speaker's name.

## The first play

The very first song may take a few seconds to settle into step: the add-on measures where each start lands and
sends the next one that much earlier or later. Its log is also kept as `engine.log` in the add-on's configuration
folder.

Run one bridge per home. If Home.io on a Mac is also set to make Google speakers AirPlay speakers, turn that off.

## Which speakers stay in time

Nest Mini, Nest Audio and Nest Hub. Other Cast devices play, but not in time with AirPlay speakers.

If one of those three can't be brought back into time (three tries, then a minute still off), the log says
"still out of time after every step" and Home.io shows it under the speaker in Music. Stop the music and start it
again.

## Built on

A fork of [PlayOnAir](https://github.com/felipefdl/play-on-air) by Felipe Lima (MIT), from its 0.4.0 release, which
carries a fork of the shairplay AirPlay 2 receiver (LGPL-3.0-or-later). The source of everything in the image is in
this repository.

Not made by, endorsed by or affiliated with Apple or Google.
