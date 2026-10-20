# The Steam program

The whole of what TurnOver's Steam support does outside TurnOver itself is here, in
[Sources/steam-speech](Sources/steam-speech): about 600 lines of Swift and the two small scripts it puts in Steam's
pages ([Scripts.swift](Sources/steam-speech/Scripts.swift)). The top of [main.swift](Sources/steam-speech/main.swift)
says what it does and what it can't.

In short:

- It turns on Steam's own debugging port (a file named `.cef-enable-remote-debugging` in Steam's folder), connects
  to Big Picture through it, and reads the item that has the focus as you move.
- It reads Steam games built on Electron that are started with `--remote-debugging-port=9223`.
- It only connects to 127.0.0.1, and only to a port that is really Steam's.
- TurnOver starts it without TurnOver's permissions: it can't read other apps, the screen or the keyboard.
- It talks to TurnOver in plain lines: `S` say, `I` interrupt and say, `X` stop, `L` log, `T` status, and `R` when
  Steam's menu opens without the keyboard (TurnOver then switches away and back, which makes Steam hand it the keys).

TurnOver builds it from this source, runs its self-test, and signs it as part of TurnOver.app
(`Contents/Helpers/steam-speech`).

```
swift build -c release
.build/release/steam-speech --self-test
```
