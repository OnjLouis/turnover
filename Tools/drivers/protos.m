// SPDX-License-Identifier: GPL-3.0-or-later
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
int main() { @autoreleasepool {
    dlopen("/System/Library/PrivateFrameworks/ScreenReader.framework/Versions/A/Frameworks/ScreenReaderOutput.framework/ScreenReaderOutput", RTLD_NOW);
    [[NSBundle bundleWithPath:@"/System/Library/ScreenReader/BrailleDrivers/BrailleConnect.brailledriver"] load];
    unsigned n; Protocol * __unsafe_unretained *ps = objc_copyProtocolList(&n);
    for (unsigned i = 0; i < n; i++) { const char *nm = protocol_getName(ps[i]); if (strncmp(nm, "SCR", 3) == 0) {
        printf("%s\n", nm);
        unsigned m; struct objc_method_description *d = protocol_copyMethodDescriptionList(ps[i], YES, YES, &m);
        for (unsigned j = 0; j < m; j++) printf("   req %s\n", sel_getName(d[j].name));
        d = protocol_copyMethodDescriptionList(ps[i], NO, YES, &m);
        for (unsigned j = 0; j < m; j++) printf("   opt %s\n", sel_getName(d[j].name));
    } }
}}
