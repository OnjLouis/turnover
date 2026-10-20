// SPDX-License-Identifier: GPL-3.0-or-later
#import <Foundation/Foundation.h>
#import <dlfcn.h>
@interface NSObject (C)
+ (id)clientWithDelegate:(id)d; - (BOOL)isConnected; - (BOOL)isConfigured; - (void)setMainAttributedString:(id)s; - (void)display;
- (void)setKeepConnectionAlive:(BOOL)b; - (void)loadDisplayWithBluetoothDeviceAddress:(id)a; - (void)setPrimaryBrailleDisplay:(int)t; - (id)driverConfiguration; - (void)setAlertString:(id)s timeout:(double)t priority:(int)p;
@end
int main() { @autoreleasepool {
    setvbuf(stdout, NULL, _IONBF, 0);
    dlopen("/System/Library/PrivateFrameworks/ScreenReader.framework/Versions/A/Frameworks/ScreenReaderOutput.framework/ScreenReaderOutput", RTLD_NOW);
    id c = [NSClassFromString(@"SCROBrailleClient") clientWithDelegate:nil];
    printf("client %s\n", [[c description] UTF8String]);
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    printf("connected %d configured %d config %s\n", [c isConnected], [c isConfigured], [[[c driverConfiguration] description] UTF8String]);
    [c setKeepConnectionAlive:YES];
    [c loadDisplayWithBluetoothDeviceAddress:@"00-00-8f-c9-4e-d2"];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:6]];
    printf("after load: configured %d config %s\n", [c isConfigured], [[[c driverConfiguration] description] UTF8String]);
    [c setAlertString:@"Hello from TurnOver" timeout:15 priority:1];
    [c setMainAttributedString:[[NSAttributedString alloc] initWithString:@"Hello from TurnOver, through scrod"]];
    [c display];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:12]];
    printf("connected %d\n", [c isConnected]);
}}
