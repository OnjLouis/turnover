# Contributing to TurnOver

Thank you for wanting to help. TurnOver is maintained in spare time, a few hours a week, so the rules below are
mostly about not wasting your time or mine.

## Ways to help

- **Report a problem** with the [issue form](../../issues/new/choose): what you did, what happened, what you expected,
  your macOS version and keyboard style. One problem per issue.
- **Make a plugin** for an app TurnOver doesn't read well yet: reading rules, labels and keys, written as data. See
  [PLUGIN-GUIDE.md](PLUGIN-GUIDE.md). This is the easiest way in, and needs no Swift.
- **Fix something**, in the code or the guides (Guides/), with a pull request.
- **Test a change** someone else has proposed and say how it went, by ear.

## Before you write code

- **Small changes**: just send the pull request.
- **Anything bigger** (a new feature, a change to how focus, speech, keys or the VoiceOver hand-over work): open an
  issue first and say what you have in mind. Those parts are shared by every app, and a change that helps one app
  can silently break another.
- **Keep what works.** TurnOver follows VoiceOver's keys in the Mac style and NVDA's in the Windows style. A change
  that alters what an existing key does needs a very good reason.

## Pull requests

- One change per pull request, with a sentence on what it fixes and how you checked it (by ear, a unit test, a
  recorded window).
- `./build.sh --no-install` must build, and the unit tests must pass. The checks run them on every pull request.
- Add a test where you can: Sources/TurnOverTests has plain tests and tests against recorded windows (TESTING.md).
- Recorded windows must not contain anyone's private content: record Apple's own content, not mail, chats or
  documents.
- Match the code around you: its naming, its comment style (comments say why, and what was seen or measured; git
  already keeps who and when), and no new dependencies without asking first.
- Security matters more than usual here: a screen reader sees everything on screen and every key. Changes that touch
  keys, the network, files, permissions or the control channel get the closest review. TurnOver connects to one place,
  its update site; keep it that way.

Nothing is merged by itself, and not everything will be merged. If a pull request isn't a fit, I'll try to say why.

## Signing off your work (DCO)

TurnOver uses the [Developer Certificate of Origin](https://developercertificate.org): by adding a `Signed-off-by` line
to each commit, you certify that you wrote the change, or otherwise have the right to submit it under the project's
licence (GPL 3.0 or later). Git adds the line for you:

```bash
git commit -s -m "Word: the next table found when the cursor is in a heading"
```

There's nothing to sign beyond that line.

## Releases

Only the project's own builds are signed, notarised and offered through TurnOver's updates. Pull requests reach users
in the next release after they're merged.

## Behaviour

Be kind and be specific. Many people here use a screen reader every day and depend on it; a report that says exactly
what was heard is worth more than one that says it's broken. See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
