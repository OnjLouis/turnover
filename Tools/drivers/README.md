# The key driver and the probes: sources

These are the maintainer's one-off probes and drivers; nothing here is needed to build or contribute.

These are the sources of the tools in `~/Library/Developer/TurnOver/tools` (the key driver, `scenario.py`, the
AX probes, the mask scripts and the runners' helpers). They were on one disk only until 16 Oct 2026; this folder
is the copy that travels with the code. The live folder is where they run from: build a tool with

    swiftc -O -o ~/Library/Developer/TurnOver/tools/<name> <name>.swift

(Objective-C ones with `clang -framework Cocoa -framework ApplicationServices`), and copy the scripts across.
`scenario.py` finds the built tools through `TURNOVER_TOOLS` (default the live folder). The scenarios themselves
are in `testing/scenarios`; the regression pass is `testing/scenarios/regression/run.sh`, described in TESTING.md.
When a live tool or scenario changes, copy it here in the same change.
