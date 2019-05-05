//
//  MenuMeterWorkarounds.m
//
//	Various workarounds for old OS bugs that may not be applicable
//  (or compilable) on newer OS versions. To prevent conflicts
//  everything here is __private_extern__.
//
//	Copyright (c) 2009-2014 Alex Harper
//
// 	This file is part of MenuMeters.
//
// 	MenuMeters is free software; you can redistribute it and/or modify
// 	it under the terms of the GNU General Public License version 2 as
//  published by the Free Software Foundation.
//
// 	MenuMeters is distributed in the hope that it will be useful,
// 	but WITHOUT ANY WARRANTY; without even the implied warranty of
// 	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// 	GNU General Public License for more details.
//
// 	You should have received a copy of the GNU General Public License
// 	along with MenuMeters; if not, write to the Free Software
// 	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//

#import "MenuMeterWorkarounds.h"
#import "AppleUndocumented.h"



@interface NSProcessInfo (MenuMetersWorkarounds)
- (BOOL)isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion)version;
@end


static BOOL SystemVersionCompare(SInt32 gestVersion, int32_t major, int32_t minor) {
		NSOperatingSystemVersion version = { major, minor, 0 };
		return [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:version];
} 

__private_extern__ BOOL OSIsJaguarOrLater(void) {
	return SystemVersionCompare(0x1020, 10, 2);
}

__private_extern__ BOOL OSIsPantherOrLater(void) {
	return SystemVersionCompare(0x1030, 10, 3);
}

__private_extern__ BOOL OSIsTigerOrLater(void) {
	return SystemVersionCompare(0x1040, 10, 4);
}

__private_extern__ BOOL OSIsLeopardOrLater(void) {
	return SystemVersionCompare(0x1050, 10, 5);
}

__private_extern__ BOOL OSIsSnowLeopardOrLater(void) {
	return SystemVersionCompare(0x1060, 10, 6);
}

__private_extern__ BOOL OSIsMavericksOrLater(void) {
	return SystemVersionCompare(0x1090, 10, 9);
}

__private_extern__ void LiveUpdateMenuItemTitle(NSMenu *menu, CFIndex index, NSString *title) {
    LiveUpdateMenuItemTitleAndVisibility(menu, index, title, NO);
}

__private_extern__ void LiveUpdateMenuItemTitleAndVisibility(NSMenu *menu, CFIndex index, NSString *title, BOOL hidden) {

	// Update a menu itm various displays. Under 10.4 the Carbon and Cocoa menus
	// were not kept in sync. This problem disappeared later (not a problem in
	// 10.5). Since x86_64 can't call Carbon we have to wrap this in our
	// own call.

	// Guard against < 1 based values (such as the output of [NSMenu indexOfItem:]
	// when the item is not found.
	if (index < 0) return;

    if (title)
        [[menu itemAtIndex:index] setTitle:title];
    [[menu itemAtIndex:index] setHidden:hidden];

} // LiveUpdateMenuItemTitle

__private_extern__ void LiveUpdateMenu(NSMenu *menu) {

} // LiveUpdateMenu

__private_extern__ BOOL IsMenuMeterMenuBarDarkThemed(void) {
	// On 10.10 there is no documented API for theme, so we'll guess a couple of different ways.
	BOOL isDark = NO;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults synchronize];
	NSString *interfaceStyle = [defaults stringForKey:@"AppleInterfaceStyle"];
    if (interfaceStyle && [interfaceStyle isEqualToString:@"Dark"]) {
		isDark = YES;
	}
	return isDark;
} // IsMenuMeterMenuBarDarkThemed

__private_extern__ NSColor * MenuItemTextColor(void) {
	// Unfortunately, there's also no NSColor API to get unselected menu item text colors.
	if (IsMenuMeterMenuBarDarkThemed()) {
		return [NSColor whiteColor];
	}	
	// Fallback
	return [NSColor blackColor];
} // MenuItemTextColor
