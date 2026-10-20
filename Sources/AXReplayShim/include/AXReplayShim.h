// SPDX-License-Identifier: GPL-3.0-or-later
// Replaying recorded accessibility trees without the applications (8 Oct 2026, from the team review).
//
// The test runner interposes the HIServices functions TurnOver calls. An element whose pid is at or above the
// replay floor is answered from a recording by handlers installed from Swift; every other element goes to the
// real function, so a recording and a live application can be read in one process.
#ifndef AXReplayShim_h
#define AXReplayShim_h
#include <ApplicationServices/ApplicationServices.h>

typedef AXError (*axreplay_attr_fn)(AXUIElementRef element, CFStringRef attribute, CFTypeRef *value);
typedef AXError (*axreplay_names_fn)(AXUIElementRef element, CFArrayRef *names);
typedef AXError (*axreplay_param_fn)(AXUIElementRef element, CFStringRef attribute, CFTypeRef parameter, CFTypeRef *value);
typedef AXError (*axreplay_action_fn)(AXUIElementRef element, CFStringRef action);
typedef AXError (*axreplay_set_fn)(AXUIElementRef element, CFStringRef attribute, CFTypeRef value);

/// Elements with a pid at or above `floor` are replayed. Pass 0 to switch replay off.
void axreplay_install(pid_t floor, axreplay_attr_fn attr, axreplay_names_fn attrNames, axreplay_names_fn paramNames,
                      axreplay_names_fn actionNames, axreplay_param_fn param, axreplay_action_fn action, axreplay_set_fn set);
/// Whether an element would be replayed.
bool axreplay_handles(AXUIElementRef element);

#endif
