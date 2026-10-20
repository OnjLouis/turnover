// SPDX-License-Identifier: GPL-3.0-or-later
// Bluetooth braille through Apple's driver: find the paired display, try the driver with a Bluetooth element.
#import <Foundation/Foundation.h>
#import <IOBluetooth/IOBluetooth.h>
#import <dlfcn.h>
@interface TOBTElement : NSObject <NSCopying>
@property int transport; @property (copy) NSString *bluetoothAddress; @property int identifier;
@end
@implementation TOBTElement
- (unsigned int)ioObject { return 0; }
- (id)copyWithZone:(NSZone *)z { TOBTElement *e = [TOBTElement new]; e.transport = _transport; e.bluetoothAddress = _bluetoothAddress; return e; }
- (BOOL)isBluetoothLowEnergy { return NO; }
@end
@interface NSObject (D)
- (int)loadDriverWithIOElement:(id)e; - (long long)mainSize; - (id)modelIdentifier; - (BOOL)setMainCells:(const char *)c length:(long long)n; - (id)getInputEvents; - (BOOL)unloadDriver;
@end
int main(int argc, const char **argv) { @autoreleasepool {
    setvbuf(stdout, NULL, _IONBF, 0);
    dlopen("/System/Library/PrivateFrameworks/ScreenReader.framework/Versions/A/Frameworks/ScreenReaderOutput.framework/ScreenReaderOutput", RTLD_NOW);
    IOBluetoothDevice *dev = nil;
    for (IOBluetoothDevice *d in [IOBluetoothDevice pairedDevices]) {
        printf("paired: %s %s connected %d\n", d.name.UTF8String, d.addressString.UTF8String, d.isConnected);
        if ([d.name hasPrefix:@"VarioUltra"]) dev = d;
    }
    if (!dev) { printf("no VarioUltra paired\n"); return 1; }
    NSBundle *b = [NSBundle bundleWithPath:@"/System/Library/ScreenReader/BrailleDrivers/BrailleConnect.brailledriver"]; [b load];
    int transports[] = {2, 1, 32, 64, 128, 8};
    for (int ti = 0; ti < 6; ti++) {
        for (NSString *addr in @[dev.addressString, [dev.addressString stringByReplacingOccurrencesOfString:@"-" withString:@":"]]) {
            TOBTElement *e = [TOBTElement new]; e.transport = transports[ti]; e.bluetoothAddress = addr;
            id driver = [[[b principalClass] alloc] init];
            __block int r = -99;
            NSDate *t0 = [NSDate date];
            r = [driver loadDriverWithIOElement:e];
            printf("transport %d address %s: load %d cells %lld model %s (%.1fs)\n", transports[ti], addr.UTF8String, r, [driver mainSize], [[[driver modelIdentifier] description] UTF8String], -[t0 timeIntervalSinceNow]);
            if (r == 0 && [driver mainSize] > 0) {
                unsigned char cells[40] = {0x0F, 0x11, 0x17, 0x15, 0x2E, 0x1D, 0x11, 0}; // "bluetooth"-ish
                [driver setMainCells:(const char *)cells length:[driver mainSize]];
                NSDate *end = [NSDate dateWithTimeIntervalSinceNow:15];
                while ([end timeIntervalSinceNow] > 0) {
                    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
                    for (id ev in [driver getInputEvents] ?: @[]) printf("event %s\n", [[ev description] UTF8String]);
                }
                [driver unloadDriver];
                return 0;
            }
            [driver unloadDriver];
        }
    }
}}
