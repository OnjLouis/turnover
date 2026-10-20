// SPDX-License-Identifier: GPL-3.0-or-later
// The pure parts of the game readers (Games.swift): the bridge's line protocol, Big Picture's focus reports, and
// which processes count as games. No port is opened.
import Foundation
import TurnOverCore

func gamesTests() {
    test("games: the bridge's lines") {
        expect(Games.bridgeCommand("S Hello from Example Game\n"), .speak("Hello from Example Game"))
        expect(Games.bridgeCommand("S   spaced  \r\n"), .speak("spaced"))
        expect(Games.bridgeCommand("X"), .stop)
        expect(Games.bridgeCommand("X\r"), .stop)
        expect(Games.bridgeCommand("S "), .ignored)
        expect(Games.bridgeCommand("S"), .ignored)
        expect(Games.bridgeCommand("Q something"), .ignored)
        expect(Games.bridgeCommand(""), .ignored)
    }
    test("games: the Steam speech program's lines, cut anywhere by the pipe, come out whole") {
        // Its words are checked by its own self-test (helpers/steam-speech, --self-test, run by build.sh).
        let whole = Data("S Library, tab\nI Play\nX\nL attached to Steam Big Picture Mode\nT Reading Big Picture.\n".utf8)
        for cut in 1..<whole.count {
            var r = HelperLines()
            let got = r.add(whole.prefix(cut)) + r.add(whole.dropFirst(cut))
            expect(got, ["S Library, tab", "I Play", "X", "L attached to Steam Big Picture Mode", "T Reading Big Picture."], "cut at \(cut)")
        }
        var r = HelperLines()
        expect(r.add(Data("S half".utf8)), [], "no line until its end")
        expect(r.add(Data(" a line\n".utf8)), ["S half a line"])
    }
    test("games: which processes are Wine's") {
        check(Games.isWineProcess(name: "Example Game.exe", path: "/private/var/folders/x/T/winetemp-abc/Example Game.exe"), "a game stub")
        check(Games.isWineProcess(name: "wine", path: "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine"), "bare wine")
        check(Games.isWineProcess(name: "steam.exe", path: ""), "the bottle's Steam by name")
        check(Games.isWineProcess(name: "wine64-preloader", path: "/Users/user/Library/Application Support/notproton/runners/current/bin/wine64-preloader"), "NotProton's runner")
        check(!Games.isWineProcess(name: "Safari", path: "/Applications/Safari.app/Contents/MacOS/Safari"), "an ordinary app")
        check(!Games.isWineProcess(name: "Terminal", path: "/System/Applications/Utilities/Terminal.app/Contents/MacOS/Terminal"), "Terminal")
    }
}
