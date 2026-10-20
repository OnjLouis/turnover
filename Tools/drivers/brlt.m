// SPDX-License-Identifier: GPL-3.0-or-later
#import <Foundation/Foundation.h>
#import <dlfcn.h>
@interface NSObject (BRLT)
+ (id)tableEnumeratorWithSystemBundlePath;
+ (id)defaultTableForLocale:(id)l;
+ (id)defaultTablesArrayForLocale:(id)l;
- (id)supportedLocales;
- (id)translatorBundles;
- (id)tablesForLocale:(id)l inBundle:(id)b;
- (id)identifier;
- (id)localizedName;
- (BOOL)supportsTranslationModeContracted;
- (id)initWithTable:(id)t;
- (id)brailleForText:(id)t locations:(id *)loc;
- (id)textForBraille:(id)b locations:(id *)loc;
- (id)initWithIdentifier:(id)i;
@end
int main(int argc, const char **argv) { @autoreleasepool {
    setvbuf(stdout, NULL, _IONBF, 0);
    dlopen("/System/Library/PrivateFrameworks/ScreenReader.framework/Versions/A/Frameworks/BrailleTranslation.framework/BrailleTranslation", RTLD_NOW);
    Class E = NSClassFromString(@"BRLTTableEnumerator");
    id en = [E tableEnumeratorWithSystemBundlePath];
    NSLocale *gb = [NSLocale localeWithLocaleIdentifier:@"en_GB"];
    id def = [E defaultTablesArrayForLocale:gb];
    for (id t in def) printf("default: %s | %s | contracted %d\n", [[t identifier] UTF8String], [[t localizedName] UTF8String], [t supportsTranslationModeContracted]);
    for (id b in [en translatorBundles]) for (id t in [en tablesForLocale:gb inBundle:b]) printf("table: %s | %s\n", [[t identifier] UTF8String], [[t localizedName] UTF8String]);
    NSString *text = @"The quick brown fox jumps over the lazy dog, and that was the knowledge.";
    for (id t in def) {
        id tr = [[NSClassFromString(@"BRLTServiceTranslator") alloc] initWithTable:t];
        id loc = nil;
        id out = [tr brailleForText:text locations:&loc];
        printf("%s -> %s (%s)\n locations %s\n", [[t identifier] UTF8String], [[out description] UTF8String], [NSStringFromClass([out class]) UTF8String], [[[loc description] substringToIndex:MIN(200,[[loc description] length])] UTF8String]);
        id back = [tr textForBraille:out locations:&loc];
        printf(" back: %s\n", [[back description] UTF8String]);
    }
}}
