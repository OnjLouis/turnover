> Archived 16 Oct 2026: history from the Bosun days, kept as it was. What it planned is either done, in the roadmap, or dropped; the code is the reference now.

# What's new in TurnOver

The newest build is first. "Reported by a tester" marks a fix for something a tester sent in. Thank you.

## 1.0, build 10

- Mail's empty lines are now read as "blank", not "non breaking space". A non-breaking space read character by character is now just "space".
- A "What's new" item in the TurnOver menu, under Updates, opens this list.

## 1.0, build 9

- Writing in Mail: Up and Down now read the right line every time, including after you delete text. Before, a caret at the end of a line was read as the empty line below it, and lines were skipped.
- Password safety: if a password box appears but macOS leaves the keyboard in the app behind it, TurnOver now holds your typing back and says so, instead of letting it go into your document.
- Privacy: TurnOver's logs no longer record anything you type.

## 1.0, build 8

- Writing an email in Mail: TurnOver now reads each whole line as you arrow through. Before, words at the ends of long lines were skipped.
- Option Right now says the word you moved over, as VoiceOver does, instead of "blank" or "comma".

## 1.0, build 7

- TurnOver's own windows, such as the update window, are now handed to VoiceOver to read automatically.
- Only one copy of the TurnOver Key helper runs. Before, two could start, and both answered Command Control T.
- The TurnOver key is now Caps Lock or Control Option to start with, so VoiceOver's VO keys work straight away.
- Check for updates now says what it found and brings the update window to the front.

## 1.0, build 4

- TurnOver menu: on a setting such as the speech rate, Left now turns it down as Right turns it up. Elsewhere Left goes back a level, and Escape closes the whole menu.
- Input Monitoring: TurnOver checks the permission directly, so it no longer keeps asking after you have turned it on. It asks only once each time it runs.
- The "Background Items Added" notice for TurnOver Key no longer comes back each time TurnOver starts.

## 1.0, build 3

- VoiceOver now comes back reliably on Macs that use VoiceOver's standard shortcut, Command F5.
- When you turn on Input Monitoring, TurnOver notices straight away, says "TurnOver is ready", and takes over in Mail, Safari and Terminal, with no restart.
- The Updates menu works as soon as TurnOver opens, before the permissions are set.

## 1.0, build 2

- Updates: TurnOver menu, Updates. Check now, check every day, or download and install updates automatically.
- The Applications list shows only apps installed on your Mac.
