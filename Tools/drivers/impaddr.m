// SPDX-License-Identifier: GPL-3.0-or-later
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>
int main(int argc, const char **argv) { @autoreleasepool {
    dlopen("/System/Library/PrivateFrameworks/ScreenReader.framework/Versions/A/Frameworks/ScreenReaderOutput.framework/ScreenReaderOutput", RTLD_NOW);
    NSBundle *b = [NSBundle bundleWithPath:@"/System/Library/ScreenReader/BrailleDrivers/BrailleConnect.brailledriver"]; [b load];
    Class c = [b principalClass];
    for (int i = 1; i < argc; i++) {
        IMP imp = class_getMethodImplementation(c, NSSelectorFromString(@(argv[i])));
        Dl_info info; dladdr((void *)imp, &info);
        printf("%s offset 0x%lx\n", argv[i], (unsigned long)((char *)imp - (char *)info.dli_fbase));
    }
}}
