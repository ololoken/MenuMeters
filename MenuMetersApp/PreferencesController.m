//
//  MenuMetersPrefPane.m
//
//    MenuMeters pref panel
//
//    Copyright (c) 2002-2014 Alex Harper
//
//     This file is part of MenuMeters.
//
//     MenuMeters is free software; you can redistribute it and/or modify
//     it under the terms of the GNU General Public License version 2 as
//  published by the Free Software Foundation.
//
//     MenuMeters is distributed in the hope that it will be useful,
//     but WITHOUT ANY WARRANTY; without even the implied warranty of
//     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//     GNU General Public License for more details.
//
//     You should have received a copy of the GNU General Public License
//     along with MenuMeters; if not, write to the Free Software
//     Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//

#import "PreferencesController.h"
#import "MenuMeterCPUExtra.h"
#import "MenuMeterDiskExtra.h"
#import "MenuMeterMemExtra.h"
#import "MenuMeterNetExtra.h"

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

///////////////////////////////////////////////////////////////
//
//    Pref pane standard methods
//
///////////////////////////////////////////////////////////////

- (void)windowDidLoad {
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
