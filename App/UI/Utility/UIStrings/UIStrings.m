//
// --------------------------------------------------------------------------
// UIStrings.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "UIStrings.h"
#import <Carbon/Carbon.h>
#import "MASShortcut.h"
#import "CGSHotKeys.h"
#import "SharedUtility.h"
#import "NSAttributedString+Additions.h"

@implementation UIStrings

/// Other code for obtaining UI strings found in RemapTableController
/// Function for getting extended button string for tooltips found in RemapTableController

+ (NSString *)stringForKeyCode:(NSInteger)keyCode {
    
    /// Get string from MASShortcut
    
    MASShortcut *shortcut = [MASShortcut shortcutWithKeyCode:keyCode modifierFlags:0];
    NSString *keyStr = shortcut.keyCodeString;
    
    return keyStr;
}

+ (NSString *)getButtonString:(MFMouseButtonNumber)buttonNumber {
    NSDictionary *buttonNumberToUIString = @{
        @1: NSLocalizedString(@"button-string.primary", @"First draft: Primary Button"),
        @2: NSLocalizedString(@"button-string.secondary", @"First draft: Secondary Button"),
        @3: NSLocalizedString(@"button-string.middle", @"First draft: Middle Button"),
    };
    NSString *buttonStr = buttonNumberToUIString[@(buttonNumber)];
    if (!buttonStr) {
        buttonStr = stringf(NSLocalizedString(@"button-string.numbered", @"First Draft: Button %@"), @(buttonNumber));
    }
    return buttonStr;
}

+ (NSString *)getButtonStringToolTip:(MFMouseButtonNumber)buttonNumber {
    NSDictionary *buttonNumberToUIString = @{
        @1: NSLocalizedString(@"button-string.tool.primary",   @"First draft: the Primary Mouse Button (also called the Left Mouse Button or Mouse Button 1)"),
        @2: NSLocalizedString(@"button-string.tool.secondary", @"First draft: the Secondary Mouse Button (also called the Right Mouse Button or Mouse Button 2)"),
        @3: NSLocalizedString(@"button-string.tool.middle",    @"First draft: the Middle Mouse Button (also called the Scroll Wheel Button or Mouse Button 3)"),
    };
    NSString *buttonStr = buttonNumberToUIString[@(buttonNumber)];
    if (!buttonStr) {
        buttonStr = stringf(NSLocalizedString(@"button-string.tool.numbered", @"First draft: Mouse Button %@"), @(buttonNumber));
    }
    return buttonStr;
}

+ (NSString *)getKeyboardModifierString:(CGEventFlags)flags {
    NSString *kb = @"";
    CGEventFlags f = flags;
    kb = [NSString stringWithFormat:@"%@%@%@%@",
          (f & kCGEventFlagMaskControl ?    @"^" : @""),
          (f & kCGEventFlagMaskAlternate ?  @"⌥" : @""),
          (f & kCGEventFlagMaskShift ?      @"⇧" : @""),
          (f & kCGEventFlagMaskCommand ?    @"⌘" : @"")];

    return kb;
}
+ (NSString *)getKeyboardModifierStringToolTip:(CGEventFlags)flags {
    NSString *kb = @"";
    CGEventFlags f = flags;
    kb = [NSString stringWithFormat:@"%@%@%@%@",
          (f & kCGEventFlagMaskControl ?    [NSLocalizedString(@"modifer-key.tool.control",  @"First draft: Control (^)") stringByAppendingString:@"-"] : @""),
          (f & kCGEventFlagMaskAlternate ?  [NSLocalizedString(@"modifer-key.tool.option",   @"First draft: Option (⌥)") stringByAppendingString:@"-"]  : @""),
          (f & kCGEventFlagMaskShift ?      [NSLocalizedString(@"modifer-key.tool.shift",    @"First draft: Shift (⇧)") stringByAppendingString:@"-"]   : @""),
          (f & kCGEventFlagMaskCommand ?    [NSLocalizedString(@"modifer-key.tool.command",  @"First draft: Command (⌘)") stringByAppendingString:@"-"] : @"")];
    if (kb.length > 0) {
        kb = [kb substringToIndex:kb.length-1]; /// Delete trailing dash
        NSArray *stringArray = [kb componentsSeparatedByString:@"-"];
        kb = [self naturalLanguageListFromStringArray:stringArray];
        kb = [@"Hold " stringByAppendingString:kb];
    }
    
    return kb;
}

+ (NSAttributedString *)getStringForSystemDefinedEvent:(MFSystemDefinedEventType)type flags:(CGEventFlags)flags {
    
    NSString *symbolName = @"questionmark.square";
    NSString *stringFallback = @"<Key without description>";
    
    if (type == kMFSystemEventTypeBrightnessDown) {
        symbolName = @"sun.min";
        stringFallback = NSLocalizedString(@"apple-key.sun.min", @"First draft: <Decrease Brightness key>");
    } else if (type == kMFSystemEventTypeBrightnessUp) {
        symbolName = @"sun.max";
        stringFallback = NSLocalizedString(@"apple-key.sun.max" , @"First draft: <Increase Brightness key>");
    } else if (type == kMFSystemEventTypeMediaBack) {
        symbolName = @"backward";
        stringFallback = NSLocalizedString(@"apple-key.backward" , @"First draft: <Rewind key>");
    } else if (type == kMFSystemEventTypeMediaPlayPause) {
        symbolName = @"playpause";
        stringFallback = NSLocalizedString(@"apple-key.playpause" , @"First draft: <Play or Pause key>");
    } else if (type == kMFSystemEventTypeMediaForward) {
        symbolName = @"forward";
        stringFallback = NSLocalizedString(@"apple-key.forward" , @"First draft: <Fast-Forward key>");
    } else if (type == kMFSystemEventTypeVolumeMute) {
        symbolName = @"speaker";
        stringFallback = NSLocalizedString(@"apple-key.speaker" , @"First draft: <Mute key>");
    } else if (type == kMFSystemEventTypeVolumeDown) {
        symbolName = @"speaker.wave.1";
        stringFallback = NSLocalizedString(@"apple-key.speaker.wave.1" , @"First draft: <Decrease Volume key>");
    } else if (type == kMFSystemEventTypeVolumeUp) {
        symbolName = @"speaker.wave.3";
        stringFallback = NSLocalizedString(@"apple-key.speaker.wave.3" , @"First draft: <Increase Volume key>");
    } else if (type == kMFSystemEventTypeKeyboardBacklightDown) {
        symbolName = @"light.min";
        stringFallback = NSLocalizedString(@"apple-key.light.min" , @"First draft: <Decrease Keyboard Brightness key>");
    } else if (type == kMFSystemEventTypeKeyboardBacklightUp) {
        symbolName = @"light.max";
        stringFallback = NSLocalizedString(@"apple-key.light.max" , @"First draft: <Increase Keyboard Brightness key>");
    } else if (type == kMFSystemEventTypePower) {
        symbolName = @"power";
        stringFallback = NSLocalizedString(@"apple-key.power" , @"First draft: <Power key>");
    } else if (type == kMFSystemEventTypeCapsLock) {
        symbolName = @"capslock";
        stringFallback = NSLocalizedString(@"apple-key.capslock" , @"First draft: ⇪");
    }
        
    /// Validate
    
    if ([symbolName isEqual: @"questionmark.square"]) {
        DDLogWarn(@"Couldn't find visualization for system event with type: %d, flags: %llu", type, flags);
    }
    
    /// Get symbol and attach it to keyStr
    NSAttributedString *keyStr = [self stringWithSymbol:symbolName fallback:stringFallback];
    NSString *flagsStr = [UIStrings getKeyboardModifierString:flags];
    return symbolStringWithModifierPrefix(flagsStr, keyStr);
}

static NSMutableDictionary *_hotKeyCache;
static CGSSymbolicHotKey _highestSymbolicHotKeyInCache = 0;

+ (NSAttributedString *)getStringForKeyCode:(CGKeyCode)keyCode flags:(CGEventFlags)flags {
    
    /// Get key string
    NSString *keyStr = [UIStrings stringForKeyCode:keyCode];
    NSString *flagsStr = [UIStrings getKeyboardModifierString:flags];
    
    if (![keyStr isEqual:@""]) {
        
        NSString *combinedString = stringf(@"%@%@", flagsStr, keyStr);
        combinedString = [self stringByTrimmingLeadingWhiteSpace:combinedString];
        /// ^ Some keyStrings have leading whitespace (name " Space") to look better with preceding modifiers. But if there are no modifiers the leading space looks weird.
        
        return [[NSAttributedString alloc] initWithString:combinedString];
        
    } else {
        /// Couldn't retrieve keyStr using MAS
        
        NSAttributedString *keyStr;
        
        /// Fallback for apple proprietary function keys
        
        /// Init
        if (!_hotKeyCache) {
            _hotKeyCache = [NSMutableDictionary dictionary];
        }
        /// Get shk
        NSNumber *symbolicHotkey;
        
        /// Try to retrieve from cache
        symbolicHotkey = _hotKeyCache[@(keyCode)][@(flags)];
        
        /// If not found in cache - search new value
        if (symbolicHotkey == nil) {
            
            CGSSymbolicHotKey shk = _highestSymbolicHotKeyInCache;
            while (shk < 512) { /// 512 is arbitrary
                                
                unichar keyEquivalent;
                CGKeyCode virtualKeyCode;
                CGSModifierFlags modifiers;
                
                CGSGetSymbolicHotKeyValue(shk, &keyEquivalent, &virtualKeyCode, &modifiers);
                if (virtualKeyCode == 126) {
                    /// Why did we put this if-statement??
                }
                
                if (_hotKeyCache[@(virtualKeyCode)] == nil) {
                    _hotKeyCache[@(virtualKeyCode)] = [NSMutableDictionary dictionary];
                }
                
                /// Store in cache for later
                _hotKeyCache[@(virtualKeyCode)][@(modifiers)] = @(shk);
                
                /// Check if shk is what we're looking for.
                if (((CGKeyCode)virtualKeyCode) == keyCode) {
                    symbolicHotkey = @(shk);
                    break;
                }
                
                shk++;
            }
        }
        
        /// If symbolicHotKey found for keyCode and flags -> generate keyStr based on symbolicHotKey
        
        if (symbolicHotkey != nil) {
            
            CGSSymbolicHotKey shk = (CGSSymbolicHotKey)symbolicHotkey.integerValue;
            
            NSString *symbolName = @"questionmark.square";
            NSString *stringFallback = NSLocalizedString(@"keyboard-key-without-description", @"First draft: <Key without description>");
            
            if (shk == kMFFunctionKeySHKMissionControl) {
                symbolName = @"rectangle.3.group";
                stringFallback = NSLocalizedString(@"apple-key.rectangle.3.group", @"First draft: <Mission Control key>");
            } else if (shk == kMFFunctionKeySHKDictation) {
                symbolName = @"mic";
                stringFallback = NSLocalizedString(@"apple-key.mic", @"First draft: <Dictation key>");
            } else if (shk == kMFFunctionKeySHKSpotlight) {
                symbolName = @"magnifyingglass";
                stringFallback = NSLocalizedString(@"apple-key.magnifyingglass", @"First draft: <Spotlight key>");
            } else if (shk == kMFFunctionKeySHKDoNotDisturb) {
                symbolName = @"moon";
                stringFallback = NSLocalizedString(@"apple-key.moon", @"First draft: <Do Not Disturb key>");
            } else if (shk == kMFFunctionKeySHKSwitchKeyboard) {
                symbolName = @"globe";
                stringFallback = NSLocalizedString(@"apple-key.globe", @"First draft: <Emoji Picker key>");
            } else if (shk == kMFFunctionKeySHKLaunchpad) {
                symbolName = @"square.grid.3x2";
                stringFallback = NSLocalizedString(@"apple-key.square.grid.3x2", @"First draft: <Launchpad key>");
            }
            
            /// Get symbol and attach it to keyStr
            keyStr = [self stringWithSymbol:symbolName fallback:stringFallback];
            
            /// Validate
            
            if ([symbolName isEqual:@"questionmark.square"]) {
                DDLogError(@"Couldn't find visualization for keyCode: %d, flags: %llu, symbolicHotKey: %@", keyCode, flags, symbolicHotkey);
            }
        }
        
        /// Append keyStr and modStr
        
        NSMutableAttributedString *result = symbolStringWithModifierPrefix(flagsStr, keyStr);
        
        return result;
    }
}

static NSMutableAttributedString *symbolStringWithModifierPrefix(NSString *flagsStr, NSAttributedString *symbolStr) {
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithString:flagsStr];
    [result appendAttributedString:symbolStr];
    return result;
}

+ (NSAttributedString *)stringWithSymbol:(NSString *)symbolName fallback:(NSString *)fallbackString {
    
    NSAttributedString *string = [NSAttributedString stringWithSymbol:symbolName hPadding:0 vOffset:0 fallback:fallbackString];
    
    /// Set weight, baselineOffset, and fontSize
    ///     This is probably very specific to displaying in the keyCaptureView. Might want to refactor and put core functionality into `NSAttributedString+Additions`
    
    string = [string attributedStringByAddingWeight:0.3];
    string = [string attributedStringByAddingBaseLineOffset:0.39];
    
    if (@available(macOS 10.14, *)) {
        if (NSApp.effectiveAppearance.name == NSAppearanceNameDarkAqua) {
            string = [string attributedStringByAddingWeight:0.4];
            string = [string attributedStringByAddingBaseLineOffset:0.39];
        }
    }
    
    string = [string attributedStringBySettingFontSize:11.4];
    
    /// Return
    
    return string;
}

+ (NSString *)naturalLanguageListFromStringArray:(NSArray<NSString *> *)stringArray {
    
    NSMutableArray<NSString *> *sa = stringArray.mutableCopy;
    
    NSString *outString;
    
    if (sa.count == 0) {
        
        outString = @"";
        
    } else if (sa.count == 1) {
        
        outString = sa[0];
        
    } else if (sa.count > 1) {
        
        NSString *lastString = sa.lastObject;
        [sa removeLastObject];
        
        NSArray *firstStrings = sa;
        
        outString = [[firstStrings componentsJoinedByString:@", "] stringByAppendingFormat:@" and %@", lastString];
    }
    
    return outString;
}

/// Helper

+ (NSString *)stringByTrimmingLeadingWhiteSpace:(NSString *)str {

    NSRange range = [str rangeOfString:@"^\\s*" options:NSRegularExpressionSearch];
    return [str stringByReplacingCharactersInRange:range withString:@""];
}

@end
