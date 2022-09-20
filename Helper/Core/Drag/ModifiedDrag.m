//
// --------------------------------------------------------------------------
// ModifyingActions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import "Constants.h"

#import "ModifiedDrag.h"
#import "ScrollModifiers.h"
#import "GestureScrollSimulator.h"
#import "ModifierManager.h"

#import "SubPixelator.h"
#import <Cocoa/Cocoa.h>

#import "TransformationUtility.h"
#import "SharedMessagePort.h"
#import "TransformationManager.h"
#import "SharedUtility.h"

#import "HelperUtility.h"

#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "SharedUtility.h"

#import "ModifiedDragOutputThreeFingerSwipe.h"
#import "ModifiedDragOutputTwoFingerSwipe.h"
#import "ModifiedDragOutputFakeDrag.h"
#import "ModifiedDragOutputAddMode.h"

#import "GlobalEventTapThread.h"

@implementation ModifiedDrag

/// Vars

static ModifiedDragState _drag;
static CGEventTapProxy _tapProxy;

+ (CGEventTapProxy)tapProxy {
    return _tapProxy;
}

/// Derived props

+ (CGPoint)pseudoPointerPosition {
    
    return CGPointMake(_drag.origin.x + _drag.originOffset.x, _drag.origin.y + _drag.originOffset.y);
}

/// Debug

+ (NSString *)modifiedDragStateDescription:(ModifiedDragState)drag {
    NSString *output = @"";
    @try {
        output = [NSString stringWithFormat:
        @"\n\
        eventTap: %@\n\
        usageThreshold: %lld\n\
        type: %@\n\
        activationState: %u\n\
        modifiedDevice: \n%@\n\
        origin: (%f, %f)\n\
        originOffset: (%f, %f)\n\
        usageAxis: %u\n\
        phase: %d\n",
                  drag.eventTap, drag.usageThreshold, drag.type, drag.activationState, drag.modifiedDevice, drag.origin.x, drag.origin.y, drag.originOffset.x, drag.originOffset.y, drag.usageAxis, drag.firstCallback
                  ];
    } @catch (NSException *exception) {
        DDLogInfo(@"Exception while generating string description of ModifiedDragState: %@", exception);
    }
    return output;
}

+ (void)load_Manual {
    
    /// Init plugins
    [ModifiedDragOutputTwoFingerSwipe load_Manual];
    
    /// Setup dispatch queue
    ///     This allows us to process events in the right order
    ///     When the eventTap and the deactivate function are driven by different threads or whatever then the deactivation can happen before we've processed all the events. This allows us to avoid that issue
    dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, -1);
    _drag.queue = dispatch_queue_create("com.nuebling.mac-mouse-fix.helper.momentum-scroll", attr);
    
    /// Set usage threshold
    _drag.usageThreshold = 7; // 20, 5
    
    /// Create mouse moved callback
    if (_drag.eventTap == nil) {
        
        CGEventTapLocation location = kCGHIDEventTap;
        CGEventTapPlacement placement = kCGHeadInsertEventTap;
        CGEventTapOptions option = /*kCGEventTapOptionListenOnly*/ kCGEventTapOptionDefault;
        /// ^ Using `Default` causes weird cursor jumping issues when clicking-dragging-and-holding during addMode. Not sure why that happens. This didn't happen in v2 while using `Default`. Not sure if `ListenOnly` has any disadvantages. Edit: In other places, I've had issues using listenOnly because it messes up the timestamps (I'm on macOS 12.4. right now). -> Trying default again.
        CGEventMask mask = CGEventMaskBit(kCGEventOtherMouseDragged) | CGEventMaskBit(kCGEventMouseMoved); /// kCGEventMouseMoved is only necessary for keyboard-only drag-modification (which we've disable because it had other problems), and maybe for AddMode to work.
        mask = mask | CGEventMaskBit(kCGEventLeftMouseDragged) | CGEventMaskBit(kCGEventRightMouseDragged); /// This is necessary for modified drag to work during a left/right click and drag. Concretely I added this to make drag and drop work. For that we only need the kCGEventLeftMouseDragged. Adding kCGEventRightMouseDragged is probably completely unnecessary. Not sure if there are other concrete applications outside of drag and drop.
        
        CFMachPortRef eventTap = [TransformationUtility createEventTapWithLocation:location mask:mask option:option placement:placement callback:eventTapCallBack runLoop:GlobalEventTapThread.runLoop];
        
        _drag.eventTap = eventTap;
    }
}

/// Interface - start

+ (NSDictionary *)initialModifiers {
    
    if (_drag.activationState == kMFModifiedInputActivationStateNone) {
        return nil;
    } else if (_drag.activationState == kMFModifiedInputActivationStateInitialized || _drag.activationState == kMFModifiedInputActivationStateInUse) {
        return _drag.initialModifiers;
    } else {
        assert(false);
    }
}

+ (void)initializeDragWithDict:(NSDictionary *)effectDict initialModifiers:(NSDictionary *)modifiers onDevice:(Device *)dev {
    
    dispatch_async(_drag.queue, ^{
        
        /// Debug
        DDLogDebug(@"INITIALIZING MODIFIEDDRAG WITH previous type %@ activationState %d, newEffectDict: %@, modifiers: %@", _drag.type, _drag.activationState, effectDict, modifiers);
        
        /// Get type
        MFStringConstant type = effectDict[kMFModifiedDragDictKeyType];
        
        /// Init static parts of _drag
        _drag.modifiedDevice = dev;
        _drag.type = type;
        _drag.effectDict = effectDict;
        _drag.initialModifiers = modifiers;
        _drag.initTime = CACurrentMediaTime();
        
        id<ModifiedDragOutputPlugin> p;
        if ([type isEqualToString:kMFModifiedDragTypeThreeFingerSwipe]) {
            p = (id<ModifiedDragOutputPlugin>)ModifiedDragOutputThreeFingerSwipe.class;
        } else if ([type isEqualToString:kMFModifiedDragTypeTwoFingerSwipe]) {
            p = (id<ModifiedDragOutputPlugin>)ModifiedDragOutputTwoFingerSwipe.class;
        } else if ([type isEqualToString:kMFModifiedDragTypeFakeDrag]) {
            p = (id<ModifiedDragOutputPlugin>)ModifiedDragOutputFakeDrag.class;
        } else if ([type isEqualToString:kMFModifiedDragTypeAddModeFeedback]) {
            p = (id<ModifiedDragOutputPlugin>)ModifiedDragOutputAddMode.class;
        } else {
            assert(false);
        }
        
        /// Link with plugin
        [p initializeWithDragState:&_drag];
        _drag.outputPlugin = p;
        
        /// Init dynamic parts of _drag
        initDragState_Unsafe();
    });
}

void initDragState_Unsafe(void) {
    
    _drag.origin = getRoundedPointerLocation();
    _drag.originOffset = (Vector){0};
    _drag.activationState = kMFModifiedInputActivationStateInitialized;
    _drag.isSuspended = NO;
    
    [_drag.outputPlugin initializeWithDragState:&_drag]; /// We just want to reset the plugin state here. The plugin will already hold ref to _drag. So this is not super pretty/semantic
    
    CGEventTapEnable(_drag.eventTap, true);
    DDLogDebug(@"\nEnabled drag eventTap");
}

static CGEventRef __nullable eventTapCallBack(CGEventTapProxy proxy, CGEventType type, CGEventRef  event, void * __nullable userInfo) {
    
    /// Store proxy
    _tapProxy = proxy;
    
    /// Catch special events
    if (type == kCGEventTapDisabledByTimeout) {
        /// Re-enable on timeout (Not sure if this ever times out)
        DDLogInfo(@"ModifiedDrag eventTap timed out. Re-enabling.");
        CGEventTapEnable(_drag.eventTap, true);
        return event;
    } else if (type == kCGEventTapDisabledByUserInput) {
        DDLogInfo(@"ModifiedDrag eventTap disabled by user input.");
        return event;
    }
    
    /// Get deltas
    
    int64_t dx = CGEventGetIntegerValueField(event, kCGMouseEventDeltaX);
    int64_t dy = CGEventGetIntegerValueField(event, kCGMouseEventDeltaY);
    
    /// ^ These are truly integer values, I'm not rounding anything / losing any info here
    /// However, the deltas seem to be pre-subpixelated, and often, both dx and dy are 0.
    
    /// Debug
    
//    DDLogDebug(@"modifiedDrag input: %lld %lld", dx, dy);
    
    /// Ignore event if both deltas are zero
    ///     We do this so the phases for the gesture scroll simulation (aka twoFingerSwipe) make sense. The gesture scroll event with phase kIOHIDEventPhaseBegan should always have a non-zero delta. If we let through zero deltas here it messes those phases up.
    ///     I think for all other types of modified drag (aside from gesture scroll simulation) this shouldn't break anything, either.
    if (dx == 0 && dy == 0) return NULL;
    
    /// Make copy of event for _drag.queue
    
    CGEventRef eventCopy = CGEventCreateCopy(event);
    
    /// Do main processing on _drag.queue
    
    dispatch_async(_drag.queue, ^{
        
        /// Interrupt
        ///     This handles race condition where _drag.eventTap is disabled right after eventTapCallBack() is called
        ///     We implemented the same idea in PointerFreeze.
        ///     Actually, the check for kMFModifiedInputActivationStateNone below has the same effect, but I think but this makes it clearer?
        
        if (!CGEventTapIsEnabled(_drag.eventTap)) {
            return;
        }
        
        /// Update originOffset
        
        _drag.originOffset.x += dx;
        _drag.originOffset.y += dy;
        
        /// Suspension
        if (_drag.isSuspended) return;
        
        /// Debug
        DDLogDebug(@"ModifiedDrag handling mouseMoved");
        
        /// Call further handler functions depending on current state
        
        MFModifiedInputActivationState st = _drag.activationState;
        
        if (st == kMFModifiedInputActivationStateNone) {
            
            /// Disabling the callback triggers this function one more time apparently
            ///     That's the only case I know where I expect this. Maybe we should log this to see what's going on.
            
        } else if (st == kMFModifiedInputActivationStateInitialized) {
            
            handleMouseInputWhileInitialized(dx, dy, eventCopy);
            
        } else if (st == kMFModifiedInputActivationStateInUse) {
            
            handleMouseInputWhileInUse(dx, dy, eventCopy);
        }
        
    });
        
    /// Return
    ///     Sending `event` or NULL here doesn't seem to make a difference. If you alter the event and send that it does have an effect though?
    
    return NULL;
}

static void handleMouseInputWhileInitialized(int64_t deltaX, int64_t deltaY, CGEventRef event) {
    
    /// Activate the modified drag if the mouse has been moved far enough from the point where the drag started
    
    Vector ofs = _drag.originOffset;
    if (MAX(fabs(ofs.x), fabs(ofs.y)) > _drag.usageThreshold) {
        
        /// Debug
        DDLogDebug(@"Modified Drag entered 'in use' state");
        
        /// Store state
        _drag.usageOrigin = getRoundedPointerLocationWithEvent(event);
        
        if (fabs(ofs.x) < fabs(ofs.y)) {
            _drag.usageAxis = kMFAxisVertical;
        } else {
            _drag.usageAxis = kMFAxisHorizontal;
        }
        
        /// Update state
        _drag.activationState = kMFModifiedInputActivationStateInUse;
        _drag.firstCallback = true;
        
        /// Notify output plugin
        [_drag.outputPlugin handleBecameInUse];
        
        /// Notify TrialCounter.swift
        [TrialCounter.shared handleUse];
        
        /// Notify other modules
        [ModifierManager handleModificationHasBeenUsedWithDevice:_drag.modifiedDevice];
        [OutputCoordinator suspendTouchDriversFromDriver:kTouchDriverModifiedDrag];
    }
}
/// Only passing in event to obtain event location to get slightly better behaviour for fakeDrag
void handleMouseInputWhileInUse(int64_t deltaX, int64_t deltaY, CGEventRef event) {
    
    /// Notifiy plugin
    
    [_drag.outputPlugin handleMouseInputWhileInUseWithDeltaX:deltaX deltaY:deltaY event:event];
    
    /// Update phase
    ///
    /// - firstCallback is used in `handleMouseInputWhileInUseWithDeltaX:...` (called above)
    /// - The first time we call `handleMouseInputWhileInUseWithDeltaX:...` during a drag, the `firstCallback` will be true. On subsequent calls, the `firstCallback` will be false.
    ///     - Indirectly communicating with the plugin through _drag is a little confusing, we might want to consider removing _drag from the plugins and sending the relevant data as arguments instead.
    
    _drag.firstCallback = false;
}

+ (void (^ _Nullable)(void))suspend {
    
    void (^ __block unsuspend)(void);
    unsuspend = nil;
    ModifiedDragState *drag = &_drag; /// So the block references the gobal value instead of copying
    
    dispatch_sync(_drag.queue, ^{
        if ((*drag).activationState != kMFModifiedInputActivationStateInUse) return;
        DDLogDebug(@"Suspending ModifiedDrag");
        deactivate_Unsafe(YES);
        (*drag).isSuspended = YES;
        [(*drag).outputPlugin suspend];
        CFTimeInterval ogTime = (*drag).initTime;
        unsuspend = ^{
            dispatch_async((*drag).queue, ^{
                if (ogTime == (*drag).initTime && (*drag).isSuspended) { /// So we don't unsuspend a different drag than the one we suspended
                    NSLog(@"UNSuspending ModifiedDrag");
                    (*drag).isSuspended = NO;
                    initDragState_Unsafe();
                    [(*drag).outputPlugin unsuspend];
                }
            });
        };
    });
    
    return unsuspend;
}

+ (void)deactivate {
    
//    DDLogDebug(@"Deactivated modifiedDrag. Caller: %@", [SharedUtility callerInfo]);
    [self deactivateWithCancel:false];
}

+ (void)deactivateWithCancel:(BOOL)cancel {
    
    dispatch_async(_drag.queue, ^{
        /// ^ Do everything on the dragQueue to ensure correct order of operations with the processing of the events from the eventTap.
        deactivate_Unsafe(cancel);
    });
}

void deactivate_Unsafe(BOOL cancel) {
    
    /// Debug
    DDLogDebug(@"modifiedDrag deactivate with state: %@", [ModifiedDrag modifiedDragStateDescription:_drag]);
    
    /// Disable supension
    _drag.isSuspended = NO;
    
    /// Handle state == none
    ///     Return immediately
    if (_drag.activationState == kMFModifiedInputActivationStateNone) return;
    
    /// Handle state == In use
    ///     Notify plugin
    if (_drag.activationState == kMFModifiedInputActivationStateInUse) {
        [_drag.outputPlugin handleDeactivationWhileInUseWithCancel:cancel];
    }
    
    /// Set state == none
    _drag.activationState = kMFModifiedInputActivationStateNone;
    
    /// Disable eventTap
    CGEventTapEnable(_drag.eventTap, false);
    
    /// Debug
    DDLogDebug(@"\nmodifiedDrag disabled drag eventTap. Caller info: %@", [SharedUtility callerInfo]);
}
                   
/// Handle interference with ModifiedScroll
///     I'm not confident this is an adequate solution.
                   
//+ (void)modifiedScrollHasBeenUsed {
//    /// It's easy to accidentally drag while trying to click and scroll. And some modifiedDrag effects can interfere with modifiedScroll effects. We built this cool ModifiedDrag `suspend()` method which effectively restarts modifiedDrag. This is cool and feels nice and has a few usability benefits, but also leads to a bunch of bugs and race conditions in its current form, so were just using `deactivate()`
//    if (_drag.activationState == kMFModifiedInputActivationStateInUse) { /// This check should probably also be performed on the _drag.queue
//        [self deactivateWithCancel:YES];
//    }
//}
    
//+ (void)suspend {
//    /// Deactivate and re-initialize
//    ///     Cool but not used cause it caused some weird bugs
//
//    if (_drag.activationState == kMFModifiedInputActivationStateNone) return;
//
//    [self deactivateWithCancel:true];
//    initDragState();
//}

#pragma mark - Helper functions

/// Get rounded pointer location

CGPoint getRoundedPointerLocation(void) {
    /// Convenience wrapper for getRoundedPointerLocationWithEvent()
    
    CGEventRef event = CGEventCreate(NULL);
    CGPoint location = getRoundedPointerLocationWithEvent(event);
    CFRelease(event);
    return location;
}
static CGPoint getRoundedPointerLocationWithEvent(CGEventRef event) {
    /// I thought it was necessary to use this on _drag.origin to calculate the _drag.usageOrigin properly.
    /// To get the _drag.usageOrigin, I used to take the _drag.origin (which is float) and add the kCGMouseEventDeltaX and DeltaY (which are ints)
    ///     But even with rounding it didn't work properly so we went over to getting usageOrigin directly from a CGEvent. I think with this new setup there might not be a  reason to use the getRoundedPointerLocation functions anymore. But I'll just leave them in because they don't break anything.
    
    CGPoint pointerLocation = CGEventGetLocation(event);
    CGPoint pointerLocationRounded = (CGPoint){ .x = floor(pointerLocation.x), .y = floor(pointerLocation.y) };
    return pointerLocationRounded;
}


@end