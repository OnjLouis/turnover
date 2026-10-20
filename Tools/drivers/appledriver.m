// SPDX-License-Identifier: GPL-3.0-or-later
// Drive a braille display through macOS's own VoiceOver driver bundle: find the display, wrap it as the driver
// expects, load the driver, write cells, and print input events. Usage: appledriver <driver name> <seconds>
#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/hid/IOHIDKeys.h>
#import <objc/runtime.h>
#import <dlfcn.h>

@interface NSObject (SCRO)
- (id)initWithIOObject:(io_object_t)o;
- (int)loadDriverWithIOElement:(id)e;
- (long long)mainSize;
- (BOOL)setMainCells:(const char *)cells length:(long long)n;
- (id)getInputEvents;
- (id)modelIdentifier;
- (BOOL)isInputEnabled;
- (int)brailleInputMode;
- (unsigned long long)interfaceVersion;
- (BOOL)unloadDriver;
@end

int main(int argc, const char **argv) {
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);
        NSString *driverName = argc > 1 ? @(argv[1]) : @"BrailleConnect";
        double seconds = argc > 2 ? atof(argv[2]) : 20;
        dlopen("/System/Library/PrivateFrameworks/ScreenReader.framework/Versions/A/Frameworks/ScreenReaderOutput.framework/ScreenReaderOutput", RTLD_NOW);
        dlopen("/System/Library/PrivateFrameworks/ScreenReader.framework/Versions/A/Frameworks/ScreenReaderBrailleDriver.framework/ScreenReaderBrailleDriver", RTLD_NOW);
        NSMutableDictionary *match = (__bridge_transfer NSMutableDictionary *)IOServiceMatching(kIOHIDDeviceKey);
        match[@kIOHIDVendorIDKey] = @0x0904;
        io_service_t svc = IOServiceGetMatchingService(kIOMainPortDefault, (__bridge_retained CFDictionaryRef)match);
        if (!svc) { printf("no BAUM HID device\n"); return 1; }
        id element = [[NSClassFromString(@"SCROIOHIDElement") alloc] initWithIOObject:svc];
        printf("element: %s\n", [[element description] UTF8String]);
        NSBundle *b = [NSBundle bundleWithPath:[NSString stringWithFormat:@"/System/Library/ScreenReader/BrailleDrivers/%@.brailledriver", driverName]];
        if (![b load]) { printf("driver would not load\n"); return 1; }
        id driver = [[[b principalClass] alloc] init];
        printf("interface version %llu\n", [driver interfaceVersion]);
        int r = [driver loadDriverWithIOElement:element];
        printf("loadDriver: %d; model %s; cells %lld; input %d; mode %d\n", r, [[[driver modelIdentifier] description] UTF8String], [driver mainSize], [driver isInputEnabled], [driver brailleInputMode]);
        long long n = [driver mainSize];
        if (n <= 0) n = 20;
        char cells[80] = {0};
        // "APPLE" in dots: A=1, P=1234, P, L=123, E=15 (bit n-1 for dot n), then dots 7-8.
        unsigned char word[] = {0x01, 0x0F, 0x0F, 0x07, 0x11, 0, 0xC0, 0xC0, 0xC0};
        memcpy(cells, word, sizeof word);
        printf("setMainCells: %d\n", [driver setMainCells:cells length:n]);
        [[NSNotificationCenter defaultCenter] addObserverForName:nil object:driver queue:nil usingBlock:^(NSNotification *note) {
            printf("notification %s\n", note.name.UTF8String);
        }];
        NSDate *end = [NSDate dateWithTimeIntervalSinceNow:seconds];
        while ([end timeIntervalSinceNow] > 0) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
            id events = [driver getInputEvents];
            if ([events count]) {
                for (id e in events) {
                    printf("event %s: %s\n", class_getName([e class]), [[e description] UTF8String]);
                }
            }
        }
        memset(cells, 0, sizeof cells);
        [driver setMainCells:cells length:n];
        [driver unloadDriver];
        printf("done\n");
    }
    return 0;
}
