// SPDX-License-Identifier: GPL-3.0-or-later
#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/hid/IOHIDKeys.h>
#import <dlfcn.h>
@interface NSObject (T)
- (id)initWithIOObject:(io_object_t)o; - (int)transport; - (id)initWithFileDescriptor:(int)fd; + (id)systemElement; - (id)bluetoothAddress;
@end
int main() { @autoreleasepool {
    dlopen("/System/Library/PrivateFrameworks/ScreenReader.framework/Versions/A/Frameworks/ScreenReaderOutput.framework/ScreenReaderOutput", RTLD_NOW);
    NSMutableDictionary *m = (__bridge_transfer NSMutableDictionary *)IOServiceMatching(kIOHIDDeviceKey); m[@kIOHIDVendorIDKey] = @0x0904;
    io_service_t s = IOServiceGetMatchingService(kIOMainPortDefault, (__bridge_retained CFDictionaryRef)m);
    if (s) printf("HID (USB) transport %d\n", [[[NSClassFromString(@"SCROIOHIDElement") alloc] initWithIOObject:s] transport]);
    printf("serial transport %d\n", [[[NSClassFromString(@"SCROIOSerialElement") alloc] initWithFileDescriptor:0] transport]);
    id v = [NSClassFromString(@"SCROVirtualIOElement") systemElement];
    printf("virtual system element transport %d address %s\n", [v transport], [[[v bluetoothAddress] description] UTF8String]);
}}
