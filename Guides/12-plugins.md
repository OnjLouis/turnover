# Plugins

A plugin teaches TurnOver an app: what to call its controls, which keys do what, what to read when something
changes, and what to keep quiet. Plugins are written as data, not code: a folder with a manifest and a few JSON
files. That means no programming, nothing a plugin can do behind your back, and anyone can read one before
installing it.

## Using one

- **The plugin library** (the TurnOver menu, Tools, Plugins, Plugin library) lists the plugins others have made.
  Each one is checked and signed before it appears, and says what it does before you install it.
- **Install from a folder or the clipboard**, in the same menu, for one someone sent you.
- **Reload plugins** after editing one.

## Making one

1. Switch to the app, then the TurnOver menu, Tools, Plugins.
2. Choose **Write a plugin for this app yourself**: TurnOver makes a starter folder with the guide, a snapshot of the
   app's window and its menus, so you can see what the app calls things.
3. Or choose **Make a plugin with** an AI: TurnOver gives it the window's labels, text and menus and its own log, with
   your typing and speech left out, and the AI writes the first draft. You read and change it.
4. Edit the files, then **Install my plugin from its folder**. Reload after each change.

The format is in [the plugin guide](https://github.com/TurnOver-For-Mac/turnover/blob/main/PLUGIN-GUIDE.md): what a
manifest holds, how a rule names a control, how a key is given a command, and the checker that finds mistakes.

## Sharing one

Plugins are shared through the plugins repository on GitHub: send yours as a pull request, where everyone can read
it. The checker runs on it, it is reviewed, and then the library's signed list carries it to everyone. The plugins
repository is at github.com/TurnOver-For-Mac/turnover-plugins.

## What a plugin can't do

Run code, reach the internet, read anything in an app it doesn't name, or change TurnOver's settings. Those limits
are the point: a screen reader sees everything on your screen, and a plugin shouldn't widen that.
