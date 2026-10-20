// SPDX-License-Identifier: GPL-3.0-or-later
// TOCatch: runs a block and catches an Objective-C exception it raises, which Swift cannot. AVAudioPlayerNode's play
// raises one when the audio device has just gone (the Mac sleeping with the lid closed), and that ended TurnOver twice
// (18 and 19 Oct 2026). Returns YES if the block ran through; NO, with the reason, if it raised.
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
BOOL TOCatch(NS_NOESCAPE void (^block)(void), NSString *_Nullable *_Nullable reason);
NS_ASSUME_NONNULL_END
