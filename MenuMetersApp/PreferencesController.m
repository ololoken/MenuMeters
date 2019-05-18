#import "PreferencesController.h"

///////////////////////////////////////////////////////////////
//
//    Private methods and constants
//
///////////////////////////////////////////////////////////////

@interface PreferencesController (PrivateMethods)

@end

@implementation PreferencesController

- (id)init {
    self = [super initWithWindowNibName:@"MenuMetersPreferencesWindow"];
    return self;
}

-(void)showWindowWithExtras:(id)sender extras:(NSMutableArray<MenuMetersMenuExtraBase*>*)extras {
    if (![[self window] isVisible]) {
        [self showWindow:sender];
        for (MenuMetersMenuExtraBase*extra in extras) {
            [prefTabs addTabViewItem:[extra getConfigPane]];
        }
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(windowWillClose:)
                                                     name:NSWindowWillCloseNotification
                                                   object:self.window];
    }
    NSInteger active = 0;
    for (MenuMetersMenuExtraBase*extra in extras) {
        if (extra == sender) {
            active = [extras indexOfObject:extra];
        }
    }
    [prefTabs selectTabViewItemAtIndex:active];
    [NSApp activateIgnoringOtherApps:YES];
    [[self window] center];
    [[self window] makeKeyAndOrderFront:self];
}

-(void)windowWillClose:(NSNotification *)notification {
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self
                                                               name:nil
                                                             object:nil];
    for (NSTabViewItem*item in [prefTabs tabViewItems]) {
        [prefTabs removeTabViewItem:item];
    }
}

@end
