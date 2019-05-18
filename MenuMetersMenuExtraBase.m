//
//  NSMenuExtraBase.m
//  MenuMeters
//
//  Created by Yuji on 2015/08/01.
//
//

#import "MenuMetersMenuExtraBase.h"
#import "MenuMetersApp/AppDelegate.h"

@implementation MenuMetersMenuExtraBase
static AppDelegate *appDelegate;

#pragma mark ABSTRACT_METHODS

- (id)getConfigPane {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (BOOL)enabled {
    [self doesNotRecognizeSelector:_cmd];
    return NO;
}

-(NSDictionary*)defaults {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (void)configFromPrefs:(id)sender {
    [self doesNotRecognizeSelector:_cmd];
}

#pragma mark -

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    [self configFromPrefs:object];
}

-(instancetype)initWithBundle:(NSBundle*)bundle
{
    self=[super initWithBundle:bundle];
    for (NSString*key in [[self defaults] allKeys]) {
        [[NSUserDefaults standardUserDefaults] addObserver:self
                                                forKeyPath:key
                                                   options:NSKeyValueObservingOptionNew
                                                   context:NULL];
    }
    // Register for 10.10 theme changes
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(configFromPrefs:)
                                                            name:kAppleInterfaceThemeChangedNotification
                                                          object:nil];
    appDelegate = (AppDelegate *)[NSApplication sharedApplication].delegate;
    return self;
}
-(void)willUnload {
    for (NSString*key in [[self defaults] allKeys]) {
        [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:key];
    }
    // Unregister any change notifications
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self
                                                               name:nil
                                                             object:nil];
    [updateTimer invalidate];
    updateTimer = nil;
    [super willUnload];
}
-(void)timerFired:(id)notused
{
    NSImage *oldCanvas = statusItem.button.image;
    NSImage *canvas = oldCanvas;
    NSSize imageSize = NSMakeSize(self.length, self.view.frame.size.height);
    NSSize oldImageSize = canvas.size;
    if (imageSize.width != oldImageSize.width || imageSize.height != oldImageSize.height) {
        canvas = [[NSImage alloc] initWithSize:imageSize];
    }
    
    NSImage *image = self.image;
    [canvas lockFocus];
    [image drawAtPoint:CGPointZero fromRect:(CGRect) {.size = image.size} operation:NSCompositeCopy fraction:1.0];
    [canvas unlockFocus];
    
    if (canvas != oldCanvas) {
        statusItem.button.image = canvas;
    } else {
        [statusItem.button displayRectIgnoringOpacity:statusItem.button.bounds];
    }
}

- (void)configDisplay:(BOOL)enabled withTimerInterval:(NSTimeInterval)interval {
    if (enabled) {
        if(!statusItem){
            statusItem=[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
            statusItem.menu = self.menu;
            statusItem.menu.delegate = self;
        }
        [updateTimer invalidate];
        updateTimer=[NSTimer timerWithTimeInterval:interval target:self selector:@selector(timerFired:) userInfo:nil repeats:YES];
        [updateTimer setTolerance:.2*interval];
        [[NSRunLoop currentRunLoop] addTimer:updateTimer forMode:NSRunLoopCommonModes];
    }else if(!enabled && statusItem){
        [updateTimer invalidate];
        [[NSStatusBar systemStatusBar] removeStatusItem:statusItem];
        statusItem=nil;
    }
}

#pragma mark NSMenuDelegate
- (void)menuNeedsUpdate:(NSMenu*)menu {
    statusItem.menu = self.menu;
    statusItem.menu.delegate = self;
}
- (void)menuWillOpen:(NSMenu*)menu {
    if ([[NSApp currentEvent] modifierFlags] & NSEventModifierFlagOption)
    {
        [appDelegate showPreferences:self];
    }
    _isMenuVisible = YES;
}
- (void)menuDidClose:(NSMenu*)menu {
    _isMenuVisible = NO;
}

@end
