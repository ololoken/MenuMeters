//
//  MenuMeterMemExtra.m
//
//	Menu Extra implementation
//
//	Copyright (c) 2002-2014 Alex Harper
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

#import "MenuMeterMemExtra.h"


///////////////////////////////////////////////////////////////
//
//	Private methods
//
///////////////////////////////////////////////////////////////

@interface MenuMeterMemExtra (PrivateMethods)

// Menu generation
- (void)updateMenuContent;

// Image renderers
- (void)renderPieIntoImage:(NSImage *)image;
- (void)renderNumbersIntoImage:(NSImage *)image;
- (void)renderBarIntoImage:(NSImage *)image;
- (void)renderPressureBar:(NSImage *)image;
- (void)renderMemHistoryIntoImage:(NSImage *)image;
- (void)renderPageIndicatorIntoImage:(NSImage *)image;

// Timer callbacks
- (void)updateMenuWhenDown;

// Prefs
- (void)configFromPrefs:(NSNotification *)notification;

@end

///////////////////////////////////////////////////////////////
//
//	Localized strings
//
///////////////////////////////////////////////////////////////

#define	kFreeLabel							@"F:"
#define	kUsedLabel							@"U:"
#define kUsageTitle							@"Memory Usage:"
#define kPageStatsTitle						@"Memory Pages:"
#define kVMStatsTitle						@"VM Statistics:"
#define kSwapStatsTitle						@"Swap Files:"
#define kUsageFormat						@"%@ used, %@ free, %@ total"
#define kActiveWiredFormat					@"%@ active, %@ wired"
#define kInactiveFreeFormat					@"%@ inactive, %@ free"
#define kCompressedFormat					@"%@ compressed (%@)"
#define kVMPagingFormat						@"%@ pageins, %@ pageouts"
#define kVMCacheFormat						@"%@ cache lookups, %@ cache hits (%@)"
#define kVMFaultCopyOnWriteFormat			@"%@ page faults, %@ copy-on-writes"
#define kSingleSwapFormat					@"%@ swap file present in %@"
#define kMultiSwapFormat					@"%@ swap files present in %@"
#define kSingleEncryptedSwapFormat			@"%@ encrypted swap file present in %@"
#define kMultiEncryptedSwapFormat			@"%@ encrypted swap files present in %@"
#define kMaxSingleSwapFormat				@"%@ swap file at peak usage"
#define kMaxMultiSwapFormat					@"%@ swap files at peak usage"
#define kSwapSizeFormat						@"%@ total swap space"
#define kSwapSizeUsedFormat					@"%@ total swap space (%@ used)"
#define kMBLabel							@"MB"

///////////////////////////////////////////////////////////////
//
//	init/unload/dealloc
//
///////////////////////////////////////////////////////////////
static NSDictionary* defaults;

@implementation MenuMeterMemExtra

-(NSDictionary*)defaults {
    if (!defaults) {
        //TODO: move to plist
        defaults = @{
                     @"kMemMenuBundleID": @YES,

                     @"kMemDisplayMode": @0,
                     
                     @"kMemUsedFreeLabel": @YES,
                     @"kMemPressure": @NO,
                     @"kMemPageIndicator": @NO,

                     @"kMemUpdateIntervalMax": @60,
                     @"kMemUpdateIntervalMin": @1,
                     @"kMemUpdateInterval": @5,

                     @"kMemGraphWidthMax": @88,
                     @"kMemGraphWidthMin": @11,
                     @"kMemGraphWidth": @33,

                     @"kMemFreeColor": [NSArchiver archivedDataWithRootObject:kMemFreeColorDefault],
                     @"kMemUsedColor": [NSArchiver archivedDataWithRootObject:kMemUsedColorDefault],
                     @"kMemActiveColor": [NSArchiver archivedDataWithRootObject:kMemActiveColorDefault],
                     @"kMemInactiveColor": [NSArchiver archivedDataWithRootObject:kMemInactiveColorDefault],
                     @"kMemWireColor": [NSArchiver archivedDataWithRootObject:kMemWireColorDefault],
                     @"kMemCompressedColor": [NSArchiver archivedDataWithRootObject:kMemCompressedColorDefault],
                     @"kMemPageInColor": [NSArchiver archivedDataWithRootObject:kMemPageInColorDefault],
                     @"kMemPageOutColor": [NSArchiver archivedDataWithRootObject:kMemPageOutColorDefault],
                     @"kMemPageRateColor": [NSArchiver archivedDataWithRootObject:kMemPageRateColorDefault]
                     };
    }
    return defaults;
}

-(id)getConfigPane {
    NSArray*viewObjects;
    [[NSBundle mainBundle] loadNibNamed:@"MEMPreferences" owner:self topLevelObjects:&viewObjects];
    for (id view in viewObjects) {
        if ([view isKindOfClass:[NSView class]]) {
            NSTabViewItem* prefView = [[NSTabViewItem alloc] init];
            [prefView setLabel:@"Memory"];
            [prefView setView:view];
            return prefView;
        }
    }
    return nil;
}

- (BOOL)enabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"kMemMenuBundleID"];
}


- initWithBundle:(NSBundle *)bundle {

	self = [super initWithBundle:bundle];
	if (!self) {
		return nil;
	}

	// Build our CPU statistics gatherer and history
	memStats = [[MenuMeterMemStats alloc] init];
	memHistory = [NSMutableArray array];
	if (!(memStats && memHistory)) {
		NSLog(@"MenuMeterMem unable to load data gatherer or storage. Abort.");
		return nil;
	}

	// Setup our menu
	extraMenu = [[NSMenu alloc] initWithTitle:@""];
	if (!extraMenu) {
		return nil;
	}
	// Disable menu autoenabling
	[extraMenu setAutoenablesItems:NO];

	// Setup menu content
	NSMenuItem *menuItem = nil;

	// Add memory usage menu items and placeholder
	menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:[bundle localizedStringForKey:kUsageTitle value:nil table:nil]
												  action:nil
										   keyEquivalent:@""];
	[menuItem setEnabled:NO];
	menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:@"" action:nil keyEquivalent:@""];
	[menuItem setEnabled:NO];

	// Add memory page stats title and placeholders
	menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:[bundle localizedStringForKey:kPageStatsTitle value:nil table:nil]
												  action:nil
										   keyEquivalent:@""];
	[menuItem setEnabled:NO];
	menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:@"" action:nil keyEquivalent:@""];
	[menuItem setEnabled:NO];
	menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:@"" action:nil keyEquivalent:@""];
	[menuItem setEnabled:NO];
	menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:@"" action:nil keyEquivalent:@""];
	[menuItem setEnabled:NO];

	// Add VM stats menu items and placeholders
	menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:[bundle localizedStringForKey:kVMStatsTitle value:nil table:nil]
												  action:nil
										   keyEquivalent:@""];
	[menuItem setEnabled:NO];
	menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:@"" action:nil keyEquivalent:@""];
	[menuItem setEnabled:NO];
	menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:@"" action:nil keyEquivalent:@""];
	[menuItem setEnabled:NO];
	menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:@"" action:nil keyEquivalent:@""];
	[menuItem setEnabled:NO];

	// Swap file stats menu item and placeholders
	menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:[bundle localizedStringForKey:kSwapStatsTitle value:nil table:nil]
												  action:nil
										   keyEquivalent:@""];
	[menuItem setEnabled:NO];
	menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:@"" action:nil keyEquivalent:@""];
	[menuItem setEnabled:NO];
	menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:@"" action:nil keyEquivalent:@""];
	[menuItem setEnabled:NO];
	menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:@"" action:nil keyEquivalent:@""];
	[menuItem setEnabled:NO];

	// Get our view
    extraView = [[MenuMeterMemView alloc] initWithFrame:[[self view] frame] menuExtra:self];
	if (!extraView) {
		return nil;
	}
    [self setView:extraView];

	// Load localized strings
	localizedStrings = [NSDictionary dictionaryWithObjectsAndKeys:
							[[NSBundle bundleForClass:[self class]] localizedStringForKey:kUsageFormat value:nil table:nil],
							kUsageFormat,
							[[NSBundle bundleForClass:[self class]] localizedStringForKey:kActiveWiredFormat value:nil table:nil],
							kActiveWiredFormat,
							[[NSBundle bundleForClass:[self class]] localizedStringForKey:kInactiveFreeFormat value:nil table:nil],
							kInactiveFreeFormat,
							[[NSBundle bundleForClass:[self class]] localizedStringForKey:kCompressedFormat value:nil table:nil],
							kCompressedFormat,
							[[NSBundle bundleForClass:[self class]] localizedStringForKey:kVMPagingFormat value:nil table:nil],
							kVMPagingFormat,
							[[NSBundle bundleForClass:[self class]] localizedStringForKey:kVMCacheFormat value:nil table:nil],
							kVMCacheFormat,
							[[NSBundle bundleForClass:[self class]] localizedStringForKey:kVMFaultCopyOnWriteFormat value:nil table:nil],
							kVMFaultCopyOnWriteFormat,
							[[NSBundle bundleForClass:[self class]] localizedStringForKey:kSingleSwapFormat value:nil table:nil],
							kSingleSwapFormat,
							[[NSBundle bundleForClass:[self class]] localizedStringForKey:kMultiSwapFormat value:nil table:nil],
							kMultiSwapFormat,
							[[NSBundle bundleForClass:[self class]] localizedStringForKey:kMaxSingleSwapFormat value:nil table:nil],
							kMaxSingleSwapFormat,
							[[NSBundle bundleForClass:[self class]] localizedStringForKey:kMaxMultiSwapFormat value:nil table:nil],
							kMaxMultiSwapFormat,
							[[NSBundle bundleForClass:[self class]] localizedStringForKey:kSingleEncryptedSwapFormat value:nil table:nil],
							kSingleEncryptedSwapFormat,
							[[NSBundle bundleForClass:[self class]] localizedStringForKey:kMultiEncryptedSwapFormat value:nil table:nil],
							kMultiEncryptedSwapFormat,
							[[NSBundle bundleForClass:[self class]] localizedStringForKey:kSwapSizeFormat value:nil table:nil],
							kSwapSizeFormat,
							[[NSBundle bundleForClass:[self class]] localizedStringForKey:kSwapSizeUsedFormat value:nil table:nil],
							kSwapSizeUsedFormat,
							[[NSBundle bundleForClass:[self class]] localizedStringForKey:kMBLabel value:nil table:nil],
							kMBLabel,
							nil];
	if (!localizedStrings) {
		return nil;
	}

	// Set up a NumberFormatter for localization. This is based on code contributed by Mike Fischer
	// (mike.fischer at fi-works.de) for use in MenuMeters.
	NSNumberFormatter *tempFormat = [[NSNumberFormatter alloc] init];
	[tempFormat setLocalizesFormat:YES];
	[tempFormat setFormat:[NSString stringWithFormat:@"#,##0.0%@", [localizedStrings objectForKey:kMBLabel]]];
	// Go through an archive/unarchive cycle to work around a bug on pre-10.2.2 systems
	// see http://cocoa.mamasam.com/COCOADEV/2001/12/2/21029.php
	memFloatMBFormatter = [NSUnarchiver unarchiveObjectWithData:[NSArchiver archivedDataWithRootObject:tempFormat]];
	[tempFormat setFormat:[NSString stringWithFormat:@"#,##0%@", [localizedStrings objectForKey:kMBLabel]]];
	memIntMBFormatter = [NSUnarchiver unarchiveObjectWithData:[NSArchiver archivedDataWithRootObject:tempFormat]];
	[tempFormat setFormat:@"#,##0"];
	prettyIntFormatter = [NSUnarchiver unarchiveObjectWithData:[NSArchiver archivedDataWithRootObject:tempFormat]];
	[tempFormat setFormat:@"##0.0%"];
	percentFormatter = [NSUnarchiver unarchiveObjectWithData:[NSArchiver archivedDataWithRootObject:tempFormat]];
	if (!(memFloatMBFormatter && memIntMBFormatter && prettyIntFormatter && percentFormatter)) {
		return nil;
	}
	// And configure directly from prefs on first load
	[self configFromPrefs:nil];

    // And hand ourself back to SystemUIServer
	NSLog(@"MenuMeterMem loaded.");
    return self;

} // initWithBundle

 // dealloc

///////////////////////////////////////////////////////////////
//
//	NSMenuExtra view callbacks
//
///////////////////////////////////////////////////////////////

- (NSImage *)image {

	// Image to render into (and return to view)
	NSImage *currentImage = [[NSImage alloc] initWithSize:NSMakeSize(menuWidth,
																	  [extraView frame].size.height - 1)];

	// Don't render without data
	if (![memHistory count]) return nil;

	switch ([[NSUserDefaults standardUserDefaults] integerForKey:@"kMemDisplayMode"]) {
		case kMemDisplayPie:
			[self renderPieIntoImage:currentImage];
			break;
		case kMemDisplayNumber:
			[self renderNumbersIntoImage:currentImage];
			break;
		case kMemDisplayBar:
      if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kMemPressure"]) {
        [self renderPressureBar:currentImage];
      }
      else {
        [self renderBarIntoImage:currentImage];
      }
			break;
		case kMemDisplayGraph:
			[self renderMemHistoryIntoImage:currentImage];
	}
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kMemPageIndicator"]) {
		[self renderPageIndicatorIntoImage:currentImage];
	}

	// Send it back for the view to render
	return currentImage;

} // image

- (NSMenu *)menu {

	// Since we want the menu and view to match data we update the data now
	// (menu is called before image for view)
	NSDictionary *currentStats = [memStats memStats];
	if (currentStats) {
		if ([[NSUserDefaults standardUserDefaults] integerForKey:@"kMemDisplayMode"] == kMemDisplayGraph) {
            NSInteger graphWidth = [[NSUserDefaults standardUserDefaults] integerForKey:@"kMemGraphWidth"];
			if ([memHistory count] >= graphWidth) {
				[memHistory removeObjectsInRange:NSMakeRange(0, [memHistory count] - graphWidth + 1)];
			}
		} else {
			[memHistory removeAllObjects];
		}
		[memHistory addObject:currentStats];
	}
	NSDictionary *newSwapStats = [memStats swapStats];
	if (newSwapStats) {
		currentSwapStats = newSwapStats;
	}

	// Update the menu content
	[self updateMenuContent];

	// Send the menu back to SystemUIServer
	return extraMenu;

} // menu

///////////////////////////////////////////////////////////////
//
//	Menu generation
//
///////////////////////////////////////////////////////////////

// This code is split out (unlike all the other meters) to deal
// with the special case. The memory meter is set to update slowly
// so we have its menu method pull new data when rendering. This prevents
// the menu from having obviously stale data when the update interval is
// long. However, by doing it this way we would pull data twice per
// timer update with the menu down if the updateMenuWhenDown method
// called the menu method directly.

- (void)updateMenuContent {
	NSString		*title = nil;

	// Fetch stats
	NSDictionary *currentMemStats = [memHistory objectAtIndex:0];
	if (!(currentMemStats && currentSwapStats)) return;

	// Usage
	title = [NSString stringWithFormat:kMenuIndentFormat,
				[NSString stringWithFormat:[localizedStrings objectForKey:kUsageFormat],
					[memFloatMBFormatter stringForObjectValue:[currentMemStats objectForKey:@"usedmb"]],
					[memFloatMBFormatter stringForObjectValue:[currentMemStats objectForKey:@"freemb"]],
					[memIntMBFormatter stringForObjectValue:[currentMemStats objectForKey:@"totalmb"]]]];
    [[extraMenu itemAtIndex:kMemUsageInfoMenuIndex] setTitle:title];
    [[extraMenu itemAtIndex:kMemUsageInfoMenuIndex] setHidden:NO];
	// Wired
	title = [NSString stringWithFormat:kMenuIndentFormat,
				[NSString stringWithFormat:[localizedStrings objectForKey:kActiveWiredFormat],
					[memFloatMBFormatter stringForObjectValue:[currentMemStats objectForKey:@"activemb"]],
					[memFloatMBFormatter stringForObjectValue:[currentMemStats objectForKey:@"wiremb"]]]];
    [[extraMenu itemAtIndex:kMemActiveWiredInfoMenuIndex] setTitle:title];
    [[extraMenu itemAtIndex:kMemActiveWiredInfoMenuIndex] setHidden:NO];
	// Inactive/Free
	title = [NSString stringWithFormat:kMenuIndentFormat,
				[NSString stringWithFormat:[localizedStrings objectForKey:kInactiveFreeFormat],
					[memFloatMBFormatter stringForObjectValue:[currentMemStats objectForKey:@"inactivemb"]],
					[memFloatMBFormatter stringForObjectValue:[currentMemStats objectForKey:@"freepagemb"]]]];
    [[extraMenu itemAtIndex:kMemInactiveFreeInfoMenuIndex] setTitle:title];
    [[extraMenu itemAtIndex:kMemInactiveFreeInfoMenuIndex] setHidden:NO];
	// Compressed
	title = [NSString stringWithFormat:kMenuIndentFormat,
				[NSString stringWithFormat:[localizedStrings objectForKey:kCompressedFormat],
					[memFloatMBFormatter stringForObjectValue:[currentMemStats objectForKey:@"compressedmb"]],
					[memFloatMBFormatter stringForObjectValue:[currentMemStats objectForKey:@"uncompressedmb"]]]];
    [[extraMenu itemAtIndex:kMemCompressedInfoMenuIndex] setTitle:title];
    [[extraMenu itemAtIndex:kMemCompressedInfoMenuIndex] setHidden:NO];
	// VM paging
	title = [NSString stringWithFormat:kMenuIndentFormat,
				[NSString stringWithFormat:[localizedStrings objectForKey:kVMPagingFormat],
					[prettyIntFormatter stringForObjectValue:[currentMemStats objectForKey:@"pageins"]],
					[prettyIntFormatter stringForObjectValue:[currentMemStats objectForKey:@"pageouts"]]]];
    [[extraMenu itemAtIndex:kMemVMPageInfoMenuIndex] setTitle:title];
    [[extraMenu itemAtIndex:kMemVMPageInfoMenuIndex] setHidden:NO];
	// VM cache
	title = [NSString stringWithFormat:kMenuIndentFormat,
				[NSString stringWithFormat:[localizedStrings objectForKey:kVMCacheFormat],
					[prettyIntFormatter stringForObjectValue:[currentMemStats objectForKey:@"lookups"]],
					[prettyIntFormatter stringForObjectValue:[currentMemStats objectForKey:@"hits"]],
					[percentFormatter stringForObjectValue:
						[NSNumber numberWithDouble:
							(double)(([[currentMemStats objectForKey:@"hits"] doubleValue] /
									  [[currentMemStats objectForKey:@"lookups"] doubleValue]) * 100.0)]]]];
    [[extraMenu itemAtIndex:kMemVMCacheInfoMenuIndex] setTitle:title];
    [[extraMenu itemAtIndex:kMemVMCacheInfoMenuIndex] setHidden:NO];
	// VM fault
	title = [NSString stringWithFormat:kMenuIndentFormat,
				[NSString stringWithFormat:[localizedStrings objectForKey:kVMFaultCopyOnWriteFormat],
					[prettyIntFormatter stringForObjectValue:[currentMemStats objectForKey:@"faults"]],
					[prettyIntFormatter stringForObjectValue:[currentMemStats objectForKey:@"cowfaults"]]]];
    [[extraMenu itemAtIndex:kMemVMFaultInfoMenuIndex] setTitle:title];
    [[extraMenu itemAtIndex:kMemVMFaultInfoMenuIndex] setHidden:NO];
	// Swap count/path, Tiger swap encryptioninfo from Michael Nordmeyer (http://goodyworks.com)
	if ([[currentSwapStats objectForKey:@"swapencrypted"] boolValue]) {
		title = [NSString stringWithFormat:kMenuIndentFormat,
					[NSString stringWithFormat:
						(([[currentSwapStats objectForKey:@"swapcount"] unsignedIntValue] > 1) ?
							[localizedStrings objectForKey:kMultiEncryptedSwapFormat] :
							[localizedStrings objectForKey:kSingleEncryptedSwapFormat]),
						[prettyIntFormatter stringForObjectValue:[currentSwapStats objectForKey:@"swapcount"]],
						[currentSwapStats objectForKey:@"swappath"]]];
	}
    [[extraMenu itemAtIndex:kMemSwapCountInfoMenuIndex] setTitle:title];
    [[extraMenu itemAtIndex:kMemSwapCountInfoMenuIndex] setHidden:NO];
	// Swap max
	title = [NSString stringWithFormat:kMenuIndentFormat,
				[NSString stringWithFormat:
					(([[currentSwapStats objectForKey:@"swapcountpeak"] unsignedIntValue] > 1) ?
						[localizedStrings objectForKey:kMaxMultiSwapFormat] :
						[localizedStrings objectForKey:kMaxSingleSwapFormat]),
					[prettyIntFormatter stringForObjectValue:[currentSwapStats objectForKey:@"swapcountpeak"]]]];
    [[extraMenu itemAtIndex:kMemSwapMaxCountInfoMenuIndex] setTitle:title];
    [[extraMenu itemAtIndex:kMemSwapMaxCountInfoMenuIndex] setHidden:NO];
	// Swap size, Tiger swap used path from Michael Nordmeyer (http://goodyworks.com)
	title = [NSString stringWithFormat:kMenuIndentFormat,
		[NSString stringWithFormat:[localizedStrings objectForKey:kSwapSizeUsedFormat],
			[memIntMBFormatter stringForObjectValue:[currentSwapStats objectForKey:@"swapsizemb"]],
			[memIntMBFormatter stringForObjectValue:[currentSwapStats objectForKey:@"swapusedmb"]]]];
    [[extraMenu itemAtIndex:kMemSwapSizeInfoMenuIndex] setTitle:title];
    [[extraMenu itemAtIndex:kMemSwapSizeInfoMenuIndex] setHidden:NO];

} // updateMenuContent

///////////////////////////////////////////////////////////////
//
//	Image renderers
//
///////////////////////////////////////////////////////////////

- (void)renderPieIntoImage:(NSImage *)image {

	// Load current stats
	float totalMB = 1.0f, activeMB = 0, inactiveMB = 0, wireMB = 0, compressedMB = 0;
	NSDictionary *currentMemStats = [memHistory objectAtIndex:0];
	if (currentMemStats) {
		totalMB = [[currentMemStats objectForKey:@"totalmb"] floatValue];
		activeMB = [[currentMemStats objectForKey:@"activemb"] floatValue];
		inactiveMB = [[currentMemStats objectForKey:@"inactivemb"] floatValue];
		wireMB = [[currentMemStats objectForKey:@"wiremb"] floatValue];
		compressedMB = [[currentMemStats objectForKey:@"compressedmb"] floatValue];
	}
	if (activeMB < 0) { activeMB = 0; };
	if (inactiveMB < 0) { inactiveMB = 0; };
	if (wireMB < 0) { wireMB = 0; };
	if (compressedMB < 0) { compressedMB = 0; };
	if (activeMB > totalMB) { activeMB = totalMB; };
	if (inactiveMB > totalMB) { inactiveMB = totalMB; };
	if (wireMB > totalMB) { wireMB = totalMB; };
	if (compressedMB > totalMB) { compressedMB = totalMB; };

	// Lock focus and draw curves around a center
	[image lockFocus];
	NSBezierPath *renderPath = nil;
	float totalArc = 0;
	NSPoint pieCenter = NSMakePoint(kMemPieDisplayWidth / 2, (float)[image size].height / 2);

	// Draw wired
	renderPath = [NSBezierPath bezierPath];
	[renderPath	appendBezierPathWithArcWithCenter:pieCenter
										   radius:(kMemPieDisplayWidth / 2)
									   startAngle:(360 * totalArc) + 90
										 endAngle:(360 * (wireMB / totalMB + totalArc)) + 90
										clockwise:NO];
	[renderPath lineToPoint:pieCenter];
	[wireColor set];
	[renderPath fill];
	totalArc += wireMB / totalMB;

	// Draw the active
	renderPath = [NSBezierPath bezierPath];
	[renderPath appendBezierPathWithArcWithCenter:pieCenter
										   radius:(kMemPieDisplayWidth / 2)
									   startAngle:(360 * totalArc) + 90
										 endAngle:(360 * (activeMB / totalMB + totalArc)) + 90
										clockwise:NO];
	[renderPath lineToPoint:pieCenter];
	[activeColor set];
	[renderPath fill];
	totalArc += activeMB / totalMB;

	// Draw the compressed
	renderPath = [NSBezierPath bezierPath];
	[renderPath appendBezierPathWithArcWithCenter:pieCenter
										   radius:(kMemPieDisplayWidth / 2)
									   startAngle:(360 * totalArc) + 90
										 endAngle:(360 * (compressedMB / totalMB + totalArc)) + 90
										clockwise:NO];
	[renderPath lineToPoint:pieCenter];
	[compressedColor set];
	[renderPath fill];
	totalArc += compressedMB / totalMB;

	// Draw the inactive
	renderPath = [NSBezierPath bezierPath];
	[renderPath appendBezierPathWithArcWithCenter:pieCenter
										   radius:(kMemPieDisplayWidth / 2)
									   startAngle:(360 * totalArc) + 90
										 endAngle:(360 * (inactiveMB / totalMB + totalArc)) + 90
										clockwise:NO];
	[renderPath lineToPoint:pieCenter];
	[inactiveColor set];
	[renderPath fill];
	totalArc += inactiveMB / totalMB;

	// Finish arc with black or gray
	if ([@"Dark" isEqualToString:[[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"]]) {
		[[NSColor darkGrayColor] set];		
	} else {
		[[NSColor blackColor] set];
	}

	// Close the circle if needed
	if (totalArc < 1) {
		renderPath = [NSBezierPath bezierPath];
		[renderPath appendBezierPathWithArcWithCenter:pieCenter
											   radius:(kMemPieDisplayWidth / 2) - 0.5f // Inset radius slightly
										   startAngle:(360 * totalArc) + 90
											 endAngle:450
											clockwise:NO];
		[renderPath setLineWidth:0.6f];  // Lighter line
		[renderPath stroke];
	}

	// Unlock focus
	[image unlockFocus];

} // renderPieIntoImage

- (void)renderNumbersIntoImage:(NSImage *)image {

	// Read in the RAM data
	double freeMB = 0, usedMB = 0;
	NSDictionary *currentMemStats = [memHistory objectAtIndex:0];
	if (currentMemStats) {
		freeMB = [[currentMemStats objectForKey:@"freemb"] doubleValue];
		usedMB = [[currentMemStats objectForKey:@"usedmb"] doubleValue];
	}
	if (freeMB < 0) freeMB = 0;
	if (usedMB < 0) usedMB = 0;

	// Lock focus
	[image lockFocus];

	// Construct strings
	NSAttributedString *renderUString = [[NSAttributedString alloc]
													initWithString:[NSString stringWithFormat:@"%.0f%@",
																		usedMB,
																		[localizedStrings objectForKey:kMBLabel]]
														attributes:[NSDictionary dictionaryWithObjectsAndKeys:
																		[NSFont systemFontOfSize:9.5f], NSFontAttributeName,
																		usedColor, NSForegroundColorAttributeName,
																		nil]];
	// Construct and draw the free string
	NSAttributedString *renderFString = [[NSAttributedString alloc]
													initWithString:[NSString stringWithFormat:@"%.0f%@",
																		freeMB,
																		[localizedStrings objectForKey:kMBLabel]]
														attributes:[NSDictionary dictionaryWithObjectsAndKeys:
																		[NSFont systemFontOfSize:9.5f], NSFontAttributeName,
																		freeColor, NSForegroundColorAttributeName,
																		nil]];

	// Draw the prerendered label
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kMemUsedFreeLabel"]) {
        [numberLabelPrerender drawAtPoint:NSMakePoint(0, 0) fromRect:NSMakeRect(0, 0, [numberLabelPrerender size].width, [numberLabelPrerender size].height) operation:NSCompositeSourceOver fraction:1.0f];
	}
	// Using NSParagraphStyle to right align clipped weird, so do it manually
	// No descenders so render lower
	[renderUString drawAtPoint:NSMakePoint(textWidth - (float)round([renderUString size].width),
										   (float)floor([image size].height / 2) - 1)];
	[renderFString drawAtPoint:NSMakePoint(textWidth - (float)round([renderFString size].width), -1)];

	// Unlock focus
	[image unlockFocus];

} // renderNumbersIntoImage

- (void)renderPressureBar:(NSImage *)image {
  // Load current stats
  float pressure = 0.2f;
  NSDictionary *currentMemStats = [memHistory objectAtIndex:0];
  if (currentMemStats) {
    pressure = [[currentMemStats objectForKey:@"mempress"] floatValue];
  }
  
  if (pressure < 0) { pressure = 0; };
  
  // Lock focus and draw
  [image lockFocus];
  float thermometerTotalHeight = (float)[image size].height - 3.0f;
  
  NSBezierPath *pressurePath = [NSBezierPath bezierPathWithRect:NSMakeRect(1.5f, 1.5f, kMemThermometerDisplayWidth - 3, thermometerTotalHeight * pressure)];
  
  NSBezierPath *framePath = [NSBezierPath bezierPathWithRect:NSMakeRect(1.5f, 1.5f, kMemThermometerDisplayWidth - 3, thermometerTotalHeight)];

  [activeColor set];
  [pressurePath fill];
  
  if ([@"Dark" isEqualToString:[[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"]]) {
    [[NSColor darkGrayColor] set];
  } else {
    [fgMenuThemeColor set];
  }
  [framePath stroke];
  
  // Reset
  [[NSColor blackColor] set];
  [image unlockFocus];
}

//  Bar mode memory view contributed by Bernhard Baehr
- (void)renderBarIntoImage:(NSImage *)image {

	// Load current stats
	float totalMB = 1.0f, activeMB = 0, inactiveMB = 0, wireMB = 0, compressedMB = 0;
	NSDictionary *currentMemStats = [memHistory objectAtIndex:0];
	if (currentMemStats) {
		totalMB = [[currentMemStats objectForKey:@"totalmb"] floatValue];
		activeMB = [[currentMemStats objectForKey:@"activemb"] floatValue];
		inactiveMB = [[currentMemStats objectForKey:@"inactivemb"] floatValue];
		wireMB = [[currentMemStats objectForKey:@"wiremb"] floatValue];
		compressedMB = [[currentMemStats objectForKey:@"compressedmb"] floatValue];
	}
	if (activeMB < 0) { activeMB = 0; };
	if (inactiveMB < 0) { inactiveMB = 0; };
	if (wireMB < 0) { wireMB = 0; };
	if (compressedMB < 0) { compressedMB = 0; };
	if (activeMB > totalMB) { activeMB = totalMB; };
	if (inactiveMB > totalMB) { inactiveMB = totalMB; };
	if (wireMB > totalMB) { wireMB = totalMB; };
	if (compressedMB > totalMB) { compressedMB = totalMB; };

	// Lock focus and draw
	[image lockFocus];
	float thermometerTotalHeight = (float)[image size].height - 3.0f;

	NSBezierPath *wirePath = [NSBezierPath bezierPathWithRect:NSMakeRect(1.5f, 1.5f, kMemThermometerDisplayWidth - 3,
																		 thermometerTotalHeight * (wireMB / totalMB))];
	NSBezierPath *activePath = [NSBezierPath bezierPathWithRect:NSMakeRect(1.5f, 1.5f, kMemThermometerDisplayWidth - 3,
																		   thermometerTotalHeight * ((wireMB + activeMB) / totalMB))];
	NSBezierPath *compressedPath = [NSBezierPath bezierPathWithRect:NSMakeRect(1.5f, 1.5f, kMemThermometerDisplayWidth - 3,
																			   thermometerTotalHeight * ((wireMB + activeMB + compressedMB) / totalMB))];
	NSBezierPath *inactivePath = [NSBezierPath bezierPathWithRect:NSMakeRect(1.5f, 1.5f, kMemThermometerDisplayWidth - 3,
																		   thermometerTotalHeight * ((wireMB + activeMB + compressedMB + inactiveMB) / totalMB))];
	NSBezierPath *framePath = [NSBezierPath bezierPathWithRect:NSMakeRect(1.5f, 1.5f, kMemThermometerDisplayWidth - 3, thermometerTotalHeight)];
	[inactiveColor set];
	[inactivePath fill];
	[compressedColor set];
	[compressedPath fill];
	[activeColor set];
	[activePath fill];
	[wireColor set];
	[wirePath fill];
	if ([@"Dark" isEqualToString:[[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"]]) {
		[[NSColor darkGrayColor] set];
	} else {
		[fgMenuThemeColor set];
	}
	[framePath stroke];

	// Reset
	[[NSColor blackColor] set];
	[image unlockFocus];

} // renderBarIntoImage

- (void)renderMemHistoryIntoImage:(NSImage *)image {

	// Construct paths
	NSBezierPath *wirePath =  [NSBezierPath bezierPath];
	NSBezierPath *activePath =  [NSBezierPath bezierPath];
	NSBezierPath *compressedPath =  [NSBezierPath bezierPath];
	NSBezierPath *inactivePath =  [NSBezierPath bezierPath];
	if (!(wirePath && activePath && inactivePath)) return;

	// Position for initial offset
	[wirePath moveToPoint:NSMakePoint(0, 0)];
	[activePath moveToPoint:NSMakePoint(0, 0)];
	[compressedPath moveToPoint:NSMakePoint(0, 0)];
	[inactivePath moveToPoint:NSMakePoint(0, 0)];

	// Loop over pixels in desired width until we're out of data
	int renderPosition = 0;
	// Graph height does not include baseline, reserve the space for real data
	// since memory usage can never be zero.
	float renderHeight = (float)[image size].height;
    NSInteger graphWidth = [[NSUserDefaults standardUserDefaults] integerForKey:@"kMemGraphWidth"];
 	for (renderPosition = 0; renderPosition < graphWidth; renderPosition++) {

		// No data at this position?
		if (renderPosition >= [memHistory count]) break;

		// Grab data
		NSDictionary *memData = [memHistory objectAtIndex:renderPosition];
		if (!memData) continue;
		float activeMB = [[memData objectForKey:@"activemb"] floatValue];
		float inactiveMB = [[memData objectForKey:@"inactivemb"] floatValue];
		float wireMB = [[memData objectForKey:@"wiremb"] floatValue];
		float compressedMB = [[memData objectForKey:@"compressedmb"] floatValue];
		float totalMB = [[memData objectForKey:@"totalmb"] floatValue];
		if (activeMB < 0) { activeMB = 0; };
		if (inactiveMB < 0) { inactiveMB = 0; };
		if (wireMB < 0) { wireMB = 0; };
		if (compressedMB < 0) { compressedMB = 0; };
		if (activeMB > totalMB) { activeMB = totalMB; };
		if (inactiveMB > totalMB) { inactiveMB = totalMB; };
		if (wireMB > totalMB) { wireMB = totalMB; };
		if (compressedMB > totalMB) { compressedMB = totalMB; };

		// Update paths (adding baseline)
		[inactivePath lineToPoint:NSMakePoint(renderPosition,
											  (inactiveMB + compressedMB + activeMB + wireMB) > totalMB ? totalMB : ((inactiveMB + compressedMB + activeMB + wireMB) / totalMB) * renderHeight)];
		[compressedPath lineToPoint:NSMakePoint(renderPosition,
											  (compressedMB + activeMB + wireMB) > totalMB ? totalMB : ((compressedMB + activeMB + wireMB) / totalMB) * renderHeight)];
		[activePath lineToPoint:NSMakePoint(renderPosition,
											(activeMB + wireMB) > totalMB ? totalMB : ((activeMB + wireMB) / totalMB) * renderHeight)];
		[wirePath lineToPoint:NSMakePoint(renderPosition,
										  wireMB / totalMB * renderHeight)];
	}

	// Return to lower edge (fill will close the graph)
	[inactivePath lineToPoint:NSMakePoint(renderPosition - 1, 0)];
	[compressedPath lineToPoint:NSMakePoint(renderPosition - 1, 0)];
	[activePath lineToPoint:NSMakePoint(renderPosition - 1, 0)];
	[wirePath lineToPoint:NSMakePoint(renderPosition - 1, 0)];


	// Render the graph
	[image lockFocus];
	[inactiveColor set];
	[inactivePath fill];
	[compressedColor set];
	[compressedPath fill];
	[activeColor set];
	[activePath fill];
	[wireColor set];
	[wirePath fill];

	// Clean up
	[[NSColor blackColor] set];
	[image unlockFocus];

} // renderMemHistoryIntoImages

// Paging indicator from Bernhard Baehr. Originally an overlay to the bar display, I liked
// it so much I broke the display out so it could be used with any mode.
- (void)renderPageIndicatorIntoImage:(NSImage *)image {

	// Read in the paging deltas
	uint64_t pageIns = 0, pageOuts = 0;
	NSDictionary *currentMemStats = [memHistory objectAtIndex:0];
	if (currentMemStats) {
		pageIns = [[currentMemStats objectForKey:@"deltapageins"] unsignedLongLongValue];
		pageOuts = [[currentMemStats objectForKey:@"deltapageouts"] unsignedLongLongValue];
	}

	// Lock focus and get height
	[image lockFocus];
	float indicatorHeight = (float)[image size].height;
	
	BOOL darkTheme = [@"Dark" isEqualToString:[[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"]];

	// Set up the pageout path
	NSBezierPath *arrow = [NSBezierPath bezierPath];
	[arrow moveToPoint:NSMakePoint(kMemPagingDisplayWidth / 2.0f + (menuWidth - kMemPagingDisplayWidth) - 0.5f, 1)];
	[arrow lineToPoint:NSMakePoint(kMemPagingDisplayWidth / 2.0f + (menuWidth - kMemPagingDisplayWidth) + 4.5f, 5.0f)];
	[arrow lineToPoint:NSMakePoint(kMemPagingDisplayWidth / 2.0f + (menuWidth - kMemPagingDisplayWidth) - 5.5f, 5.0f)];
	[arrow closePath];
	// Draw
	if (pageIns) {
		[pageInColor set];
	} else {
		if (darkTheme) {
			[[NSColor darkGrayColor] set];
		} else {
			[[pageInColor colorWithAlphaComponent:0.25f] set];
		}
	}
	[arrow fill];

	// Set up the pagein path
	arrow = [NSBezierPath bezierPath];
	[arrow moveToPoint:NSMakePoint(kMemPagingDisplayWidth / 2.0f + (menuWidth - kMemPagingDisplayWidth) - 0.5f, indicatorHeight - 1)];
	[arrow lineToPoint:NSMakePoint(kMemPagingDisplayWidth / 2.0f + (menuWidth - kMemPagingDisplayWidth) + 4.5f, indicatorHeight - 5.0f)];
	[arrow lineToPoint:NSMakePoint(kMemPagingDisplayWidth / 2.0f + (menuWidth - kMemPagingDisplayWidth) - 5.5f, indicatorHeight - 5.0f)];
	[arrow closePath];
	// Draw
	if (pageOuts) {
		[pageOutColor set];
	} else {
		if (darkTheme) {
			[[NSColor darkGrayColor] set];
		} else {
			[[pageOutColor colorWithAlphaComponent:0.25f] set];
		}
	}
	[arrow fill];

	// Draw the activity count
	NSString *countString = nil;
	if ((pageIns + pageOuts) >= 1000) {
		countString = @"1k+";
	} else {
		countString = [NSString stringWithFormat:@"%d", (int)(pageIns + pageOuts)];
	}
	NSAttributedString *renderString = [[NSAttributedString alloc]
											initWithString:countString
												attributes:[NSDictionary dictionaryWithObjectsAndKeys:
																[NSFont systemFontOfSize:9.5f], NSFontAttributeName,
																fgMenuThemeColor, NSForegroundColorAttributeName,
																nil]];
	// Using NSParagraphStyle to right align clipped weird, so do it manually
	// Also draw low to ignore descenders
	NSSize renderSize = [renderString size];
	[renderString drawAtPoint:NSMakePoint(menuWidth - kMemPagingDisplayWidth +
											roundf((kMemPagingDisplayWidth - (float)renderSize.width) / 2.0f),
										  4.0f)];  // Just hardcode the vertical offset

	// Unlock focus
	[image unlockFocus];

} // renderPageIndicator

///////////////////////////////////////////////////////////////
//
//	Timer callbacks
//
///////////////////////////////////////////////////////////////

- (void)timerFired:(NSTimer *)timer {

	NSDictionary *currentStats = [memStats memStats];
	if (!currentStats) return;

	// Add to history (at least one)
	if ([[NSUserDefaults standardUserDefaults] integerForKey:@"kMemDisplayMode"] == kMemDisplayGraph) {
        NSInteger graphWidth = [[NSUserDefaults standardUserDefaults] integerForKey:@"kMemGraphWidth"];
		if ([memHistory count] >= graphWidth) {
			[memHistory removeObjectsInRange:NSMakeRange(0, [memHistory count] - graphWidth + 1)];
		}
	} else {
		[memHistory removeAllObjects];
	}
	[memHistory addObject:currentStats];

	// If the menu is down, update it
	if (self.isMenuVisible) {
		[self updateMenuWhenDown];
	}
	[super timerFired:timer];
} // timerFired

- (void)updateMenuWhenDown {

	NSDictionary *newSwapStats = [memStats swapStats];
	if (newSwapStats) {
		currentSwapStats = newSwapStats;
	}

	// Update the menu content
	[self updateMenuContent];

} // updateMenuWhenDown

///////////////////////////////////////////////////////////////
//
//	Prefs
//
///////////////////////////////////////////////////////////////

- (void)configFromPrefs:(NSNotification *)notification {
    [super configDisplay:[[NSUserDefaults standardUserDefaults] doubleForKey:@"kMemMenuBundleID"]
       withTimerInterval:[[NSUserDefaults standardUserDefaults] floatForKey:@"kMemUpdateInterval"]];

	// Handle menubar theme changes
    fgMenuThemeColor = [@"Dark" isEqualToString:[[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"]]
        ? [NSColor whiteColor]
        : [NSColor blackColor];
	
	// Cache colors to skip archive cycle from prefs
    freeColor = kMemFreeColorDefault;
    if ([[NSUserDefaults standardUserDefaults] dataForKey:@"kMemFreeColor"]) {
        freeColor = [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults]
                                               dataForKey:@"kMemFreeColor"]];
    }
    usedColor = kMemUsedColorDefault;
    if ([[NSUserDefaults standardUserDefaults] dataForKey:@"kMemUsedColor"]) {
        usedColor = [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults]
                                                       dataForKey:@"kMemUsedColor"]];
    }
    activeColor = kMemActiveColorDefault;
    if ([[NSUserDefaults standardUserDefaults] dataForKey:@"kMemActiveColor"]) {
        activeColor = [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults]
                                                         dataForKey:@"kMemActiveColor"]];
    }
    inactiveColor = kMemInactiveColorDefault;
    if ([[NSUserDefaults standardUserDefaults] dataForKey:@"kMemInactiveColor"]) {
        inactiveColor = [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults]
                                                           dataForKey:@"kMemInactiveColor"]];
    }
    wireColor = kMemWireColorDefault;
    if ([[NSUserDefaults standardUserDefaults] dataForKey:@"kMemWireColor"]) {
        wireColor = [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults]
                                                       dataForKey:@"kMemWireColor"]];
    }
    compressedColor = kMemCompressedColorDefault;
    if ([[NSUserDefaults standardUserDefaults] dataForKey:@"kMemCompressedColor"]) {
        compressedColor = [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults]
                                                             dataForKey:@"kMemCompressedColor"]];
    }
    pageInColor = kMemPageInColorDefault;
    if ([[NSUserDefaults standardUserDefaults] dataForKey:@"kMemPageInColor"]) {
        pageInColor = [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults]
                                                         dataForKey:@"kMemPageInColor"]];
    }
    pageOutColor = kMemPageOutColorDefault;
    if ([[NSUserDefaults standardUserDefaults] dataForKey:@"kMemPageOutColor"]) {
        pageOutColor = [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults]
                                                          dataForKey:@"kMemPageOutColor"]];
    }

	// Since text rendering is so CPU intensive we minimize this by
	// prerendering what we can if we need it
	numberLabelPrerender = nil;
	NSAttributedString *renderUString = [[NSAttributedString alloc]
											initWithString:[[NSBundle bundleForClass:[self class]]
															   localizedStringForKey:kUsedLabel
																			   value:nil
																			   table:nil]
												attributes:[NSDictionary dictionaryWithObjectsAndKeys:
																[NSFont systemFontOfSize:9.5f], NSFontAttributeName,
																usedColor, NSForegroundColorAttributeName,
																nil]];
	NSAttributedString *renderFString = [[NSAttributedString alloc]
											initWithString:[[NSBundle bundleForClass:[self class]]
																localizedStringForKey:kFreeLabel
																				value:nil
																				table:nil]
												attributes:[NSDictionary dictionaryWithObjectsAndKeys:
																[NSFont systemFontOfSize:9.5f], NSFontAttributeName,
																freeColor, NSForegroundColorAttributeName,
																nil]];
	if ([renderUString size].width > [renderFString size].width) {
		numberLabelPrerender = [[NSImage alloc] initWithSize:NSMakeSize([renderUString size].width,
																		[extraView frame].size.height - 1)];
	} else {
		numberLabelPrerender = [[NSImage alloc] initWithSize:NSMakeSize([renderFString size].width,
																		[extraView frame].size.height - 1)];
	}
	[numberLabelPrerender lockFocus];
	// No descenders so render both lines lower than normal
	[renderUString drawAtPoint:NSMakePoint(0, (float)floor([numberLabelPrerender size].height / 2) - 1)];
	[renderFString drawAtPoint:NSMakePoint(0, -1)];
	[numberLabelPrerender unlockFocus];

	// Figure out the length of "MB" localization
	float mbLength = 0;
    NSInteger displayMode = [[NSUserDefaults standardUserDefaults] integerForKey:@"kMemDisplayMode"];
	if (displayMode == kMemDisplayNumber) {
		NSAttributedString *renderMBString =  [[NSAttributedString alloc]
													initWithString:[localizedStrings objectForKey:kMBLabel]
														attributes:[NSDictionary dictionaryWithObjectsAndKeys:
																		[NSFont systemFontOfSize:9.5f], NSFontAttributeName,
																		nil]];
		mbLength = (float)ceil([renderMBString size].width);
	}

	// Fix our menu size to match our config
	menuWidth = 0;
	switch (displayMode) {
		case kMemDisplayPie:
			menuWidth = kMemPieDisplayWidth;
			break;
		case kMemDisplayNumber:
			// Read in the total RAM, and change length to accomodate those with more RAM
			if ([[[memStats memStats] objectForKey:@"totalmb"] unsignedLongLongValue] >= 10000) {
				menuWidth = kMemNumberDisplayExtraLongWidth + mbLength;
				textWidth = kMemNumberDisplayExtraLongWidth + mbLength;
			} else if ([[[memStats memStats] objectForKey:@"totalmb"] unsignedLongLongValue] >= 1000) {
				menuWidth = kMemNumberDisplayLongWidth + mbLength;
				textWidth = kMemNumberDisplayLongWidth + mbLength;
			} else {
				menuWidth = kMemNumberDisplayShortWidth + mbLength;
				textWidth = kMemNumberDisplayShortWidth + mbLength;
			}
			if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kMemUsedFreeLabel"]) {
				menuWidth += (float)ceil([numberLabelPrerender size].width);
				textWidth += (float)ceil([numberLabelPrerender size].width);
			}
			break;
		case kMemDisplayBar:
			menuWidth = kMemThermometerDisplayWidth;
			break;
		case kMemDisplayGraph:
			menuWidth = [[NSUserDefaults standardUserDefaults] integerForKey:@"kMemGraphWidth"];
			break;
	}
	// Adjust width for paging indicator
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kMemPageIndicator"]) {
		menuWidth += kMemPagingDisplayWidth + kMemPagingDisplayGapWidth;
	}

	// Resize the view
	[extraView setFrameSize:NSMakeSize(menuWidth, [extraView frame].size.height)];
	[self setLength:menuWidth];

	// Force initial update
	[self timerFired:nil];
} // configFromPrefs

@end
