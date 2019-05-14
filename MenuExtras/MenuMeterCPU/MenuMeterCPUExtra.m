//
//  MenuMeterCPUExtra.m
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

#import "MenuMeterCPUExtra.h"

///////////////////////////////////////////////////////////////
//
//	Private methods
//
///////////////////////////////////////////////////////////////

@interface MenuMeterCPUExtra (PrivateMethods)
-(NSDictionary*)defaults;

// Image renderers
- (void)renderHistoryGraphIntoImage:(NSImage *)image forProcessor:(uint32_t)processor atOffset:(float)offset;
- (void)renderSinglePercentIntoImage:(NSImage *)image forProcessor:(uint32_t)processor atOffset:(float)offset;
- (void)renderSplitPercentIntoImage:(NSImage *)image forProcessor:(uint32_t)processor atOffset:(float)offset;
- (void)renderThermometerIntoImage:(NSImage *)image forProcessor:(uint32_t)processor atOffset:(float)offset;
- (void)renderHorizontalThermometerIntoImage:(NSImage *)image forProcessor:(uint32_t)processor atX:(float)x andY:(float)y withWidth:(float)width andHeight:(float)height;

// Timer callbacks
- (void)updateMenuWhenDown;

// Menu actions
- (void)openProcessViewer:(id)sender;
- (void)openActivityMonitor:(id)sender;
- (void)openConsole:(id)sender;

// Prefs
- (void)configFromPrefs:(NSNotification *)notification;

// Utilities
- (uint32_t)numberOfCPUsToDisplay;
- (void)getCPULoadForCPU:(uint32_t)processor
            returnSystem:(double *)system
              returnUser:(double *)user;
- (void)getCPULoadFromLoad:(MenuMeterCPULoad *)load
            returnSystem:(double *)system
              returnUser:(double *)user;

@end


///////////////////////////////////////////////////////////////
//
//	Localized strings
//
///////////////////////////////////////////////////////////////

#define kSingleProcessorTitle				@"Processor:"
#define kMultiProcessorTitle				@"Processors:"
#define kUptimeTitle						@"Uptime:"
#define kTaskThreadTitle					@"Tasks/Threads:"
#define kLoadAverageTitle					@"Load Average (1m, 5m, 15m):"
#define kProcessTitle                       @"Top CPU Intensive Processes:"
#define kOpenProcessViewerTitle				@"Open Process Viewer"
#define kOpenActivityMonitorTitle			@"Open Activity Monitor"
#define kOpenConsoleTitle					@"Open Console"
#define kNoInfoErrorMessage					@"No info available"


///////////////////////////////////////////////////////////////
//
//	init/unload/dealloc
//
///////////////////////////////////////////////////////////////
NSDictionary *const CPU_DEFAULTS;

static NSDictionary* defaults;
static NSInteger processMenuItems = 0;
static NSImage* defaultIcon;

@implementation MenuMeterCPUExtra
-(NSDictionary*)defaults {
    if (!defaults) {
        //TODO: move to plist
        defaults = @{
                     @"kCPUMenuBundleID": @YES,

                     @"kCPUUpdateIntervalMin": @0.5f,
                     @"kCPUUpdateIntervalMax": @10.0f,
                     @"kCPUUpdateInterval": @1.5f,

                     @"kCPUProcessCountMin": @0,
                     @"kCPUProcessCountMax": @25,
                     @"kCPUProcessCount": @5,

                     @"kCPUGraphWidthMin": @11,
                     @"kCPUGraphWidthMax": @88,
                     @"kCPUGraphWidth": @33,

                     @"kCPUHorizontalRowsMin": @1,
                     @"kCPUHorizontalRowsMax": @8,
                     @"kCPUHorizontalRows": @2,

                     @"kCPUDisplayMode": [NSNumber numberWithInt:kCPUDisplayDefault],

                     @"kCPUPercentDisplay": [NSNumber numberWithInt:kCPUPercentDisplayDefault],

                     @"kCPUSystemColor": [NSArchiver archivedDataWithRootObject:kCPUSystemColorDefault],
                     @"kCPUUserColor": [NSArchiver archivedDataWithRootObject:kCPUUserColorDefault],
                     @"kCPUTemperatureColor": [NSArchiver archivedDataWithRootObject:kCPUTemperatureColorDefault],

                     @"kCPUHorizontalWidthMin": @60,
                     @"kCPUHorizontalWidthMax": @400,
                     @"kCPUHorizontalWidth": @120,

                     @"kCPUAvgAllProcs": @NO,
                     @"kCPUAvgLowerHalfProcs": @NO,
                     @"kCPUSortByUsage": @NO,
                     @"kCPUShowTemperature": @YES,
                     };
    }
    return defaults;
}

-(id)getConfigPane {
    NSArray*viewObjects;
    [[NSBundle mainBundle] loadNibNamed:@"CPUPreferences" owner:self topLevelObjects:&viewObjects];
    for (id view in viewObjects) {
        if ([view isKindOfClass:[NSView class]]) {
            NSTabViewItem* prefView = [[NSTabViewItem alloc] init];
            [prefView setLabel:@"CPU"];
            [prefView setView:view];
            return prefView;
        }
    }
    return nil;
}

- (BOOL)enabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"kCPUMenuBundleID"];
}


- initWithBundle:(NSBundle *)bundle {

	self = [super initWithBundle:bundle];
	if (!self) {
		return nil;
	}

	// Data gatherers and storage
	cpuInfo = [[MenuMeterCPUStats alloc] init];
    cpuTopProcesses = [[MenuMeterCPUTopProcesses alloc] init];
	uptimeInfo = [[MenuMeterUptime alloc] init];
	loadHistory = [NSMutableArray array];
	if (!(cpuInfo && uptimeInfo && loadHistory && cpuTopProcesses)) {
		NSLog(@"MenuMeterCPU unable to load data gatherers or storage. Abort.");
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

	// Add processor info which never changes
    if ([cpuInfo numberOfCPUsByCombiningLowerHalf:NO] > 1) {
		menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:[bundle localizedStringForKey:kMultiProcessorTitle value:nil table:nil]
													  action:nil
											   keyEquivalent:@""];
	} else {
		menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:[bundle localizedStringForKey:kSingleProcessorTitle value:nil table:nil]
													  action:nil
											   keyEquivalent:@""];
	}
	[menuItem setEnabled:NO];
	menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:[NSString stringWithFormat:kMenuIndentFormat, [cpuInfo processorDescription]]
												  action:nil
										   keyEquivalent:@""];
	[menuItem setEnabled:NO];

	// Add uptime title and blank for uptime display
	menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:[bundle localizedStringForKey:kUptimeTitle value:nil table:nil]
												  action:nil
										   keyEquivalent:@""];
	[menuItem setEnabled:NO];
	menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:@"" action:nil keyEquivalent:@""];
	[menuItem setEnabled:NO];

	// Add task title and blanks for task display
	menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:[bundle localizedStringForKey:kTaskThreadTitle value:nil table:nil]
												  action:nil
										   keyEquivalent:@""];
	[menuItem setEnabled:NO];
	menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:@"" action:nil keyEquivalent:@""];
	[menuItem setEnabled:NO];

	// Add load title and blanks for load display
	menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:[bundle localizedStringForKey:kLoadAverageTitle value:nil table:nil]
												  action:nil
										   keyEquivalent:@""];
	[menuItem setEnabled:NO];
	menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:@"" action:nil keyEquivalent:@""];
	[menuItem setEnabled:NO];

    // Add title for top most CPU intensive processes
    menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:[bundle localizedStringForKey:kProcessTitle value:nil table:nil]
                                                  action:nil
                                           keyEquivalent:@""];
    [menuItem setEnabled:NO];

	// And the "Open Process Viewer"/"Open Activity Monitor" and "Open Console" item
	[extraMenu addItem:[NSMenuItem separatorItem]];
	menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:[bundle localizedStringForKey:kOpenActivityMonitorTitle value:nil table:nil]
												  action:@selector(openActivityMonitor:)
										   keyEquivalent:@""];
	[menuItem setTarget:self];
	menuItem = (NSMenuItem *)[extraMenu addItemWithTitle:[bundle localizedStringForKey:kOpenConsoleTitle value:nil table:nil]
												  action:@selector(openConsole:)
										   keyEquivalent:@""];
	[menuItem setTarget:self];

	// Get our view
	extraView = [[MenuMeterCPUView alloc] initWithFrame:[[self view] frame] menuExtra:self];
	if (!extraView) {
		return nil;
	}
	[self setView:extraView];
	// And configure directly from prefs on first load
	[self configFromPrefs:nil];

	// And hand ourself back to SystemUIServer
	NSLog(@"MenuMeterCPU loaded.");

	return self;

} // initWithBundle

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    [self configFromPrefs:nil];
}

 // dealloc

///////////////////////////////////////////////////////////////
//
//	NSMenuExtraView callbacks
//
///////////////////////////////////////////////////////////////

- (NSImage *)image {

	// Image to render into (and return to view)
	NSImage *currentImage = [[NSImage alloc] initWithSize:NSMakeSize((float)menuWidth,
																	  [extraView frame].size.height - 1)];
	if (!currentImage) return nil;

	// Don't render without data
	if (![loadHistory count]) return nil;

    uint32_t cpuCount = [self numberOfCPUsToDisplay];
    float renderOffset = 0.0f;
    // Horizontal CPU thermometer is handled differently because it has to
    // manage rows and columns in a very different way from normal horizontal
    // layout
    BOOL cpuShowTemperature = [[NSUserDefaults standardUserDefaults] boolForKey:@"kCPUShowTemperature"];
    if (cpuShowTemperature) {
        [self renderSingleTemperatureIntoImage:currentImage atOffset:renderOffset];
        renderOffset += kCPUTemperatureDisplayWidth;
    }
    long mode = [[NSUserDefaults standardUserDefaults] integerForKey:@"kCPUDisplayMode"]+1;
    if (mode & kCPUDisplayHorizontalThermometer) {
        // Calculate the minimum number of columns that will be needed
        long rowCount = [[NSUserDefaults standardUserDefaults] integerForKey:@"kCPUHorizontalRows"];
        //ceil(A/B) for ints is equal (A+B-1)/B
        long columnCount = (cpuCount+rowCount-1)/rowCount;
        // Calculate a column width
        float columnWidth = (menuWidth - 1.0f) / columnCount;
        if (cpuShowTemperature) {
            columnWidth -= kCPUTemperatureDisplayWidth;
        }
        // Image height
        float imageHeight = (float) ([currentImage size].height);
        // Calculate a thermometer height
        float thermometerHeight = ((imageHeight - 2) / rowCount);
        for (uint32_t cpuNum = 0; cpuNum < cpuCount; cpuNum++) {
            float xOffset = renderOffset + ((cpuNum / rowCount) * columnWidth) + 1.0f;
            float yOffset = (imageHeight -
                             (((cpuNum % rowCount) + 1) * thermometerHeight)) - 1.0f;
            [self renderHorizontalThermometerIntoImage:currentImage forProcessor:cpuNum atX:xOffset andY:yOffset withWidth:columnWidth andHeight:thermometerHeight];
        }
    }
    else {
		// Loop by processor
		for (uint32_t cpuNum = 0; cpuNum < cpuCount; cpuNum++) {
			
			// Render graph if needed
			if (mode & kCPUDisplayGraph) {
				[self renderHistoryGraphIntoImage:currentImage forProcessor:cpuNum atOffset:renderOffset];
				// Adjust render offset
				renderOffset += [[NSUserDefaults standardUserDefaults] integerForKey:@"kCPUGraphWidth"];
			}
			// Render percent if needed
			if (mode & kCPUDisplayPercent) {
				if ([[NSUserDefaults standardUserDefaults] integerForKey:@"kCPUPercentDisplay"] == kCPUPercentDisplaySplit) {
					[self renderSplitPercentIntoImage:currentImage forProcessor:cpuNum atOffset:renderOffset];
				} else {
					[self renderSinglePercentIntoImage:currentImage forProcessor:cpuNum atOffset:renderOffset];
				}
				renderOffset += percentWidth;
			}
			if (mode & kCPUDisplayThermometer) {
				[self renderThermometerIntoImage:currentImage forProcessor:cpuNum atOffset:renderOffset];
				renderOffset += kCPUThermometerDisplayWidth;
			}
			// At end of each proc adjust spacing
			renderOffset += kCPUDisplayMultiProcGapWidth;

			// If we're averaging all we're done on first iteration
			if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kCPUAvgAllProcs"]) break;
		}
    }

	// Send it back for the view to render
	return currentImage;

} // image

- (NSMenu *)menu {
    if (!defaultIcon) {
        defaultIcon = [[NSWorkspace sharedWorkspace] iconForFile:@"/bin/bash"];
    }

	// Update the various displays starting with uptime
	NSString *title = [NSString stringWithFormat:kMenuIndentFormat, [uptimeInfo uptime]];
	if (title) LiveUpdateMenuItemTitle(extraMenu, kCPUUptimeInfoMenuIndex, title);
    
	// Tasks
	title = [NSString stringWithFormat:kMenuIndentFormat, [cpuInfo currentProcessorTasks]];
	if (title) LiveUpdateMenuItemTitle(extraMenu, kCPUTaskInfoMenuIndex, title);
    
	// Load
	title = [NSString stringWithFormat:kMenuIndentFormat, [cpuInfo loadAverage]];
	if (title) LiveUpdateMenuItemTitle(extraMenu, kCPULoadInfoMenuIndex, title);
    
    // Top CPU intensive processes
    NSUInteger cpuTopProcessesCount = [[NSUserDefaults standardUserDefaults] integerForKey:@"kCPUProcessCount"];
    NSArray* processes = cpuTopProcessesCount > 0
        ? [cpuTopProcesses runningProcessesByCPUUsage:cpuTopProcessesCount]
        : @[];
    [extraMenu itemAtIndex:kCPUProcessLabelMenuIndex].hidden = processes.count == 0;
    for (NSInteger ndx = 0; ndx < MAX(processes.count, processMenuItems); ndx++) {
        if (processMenuItems <= ndx) {
            processMenuItems++;
            [[extraMenu insertItemWithTitle:@"" action:nil
                              keyEquivalent:@"" atIndex:kCPUProcessMenuIndex + ndx]
             setEnabled:NO];
        }
        if (ndx < processes.count) {
            NSDictionary* proc = processes[ndx];
            title = [NSString stringWithFormat:kMenuIndentFormat, [NSString stringWithFormat:@"%@ (%.1f%%)",
                                                                   proc[kProcessListItemProcessNameKey],
                                                                   [proc[kProcessListItemCPUKey] floatValue]
                                                                   ]];
            NSImage*icon = [NSRunningApplication runningApplicationWithProcessIdentifier:[proc[kProcessListItemPIDKey] intValue]].icon ?: defaultIcon;
            icon.size = NSMakeSize(16, 16);

            NSMenuItem*mi = [extraMenu itemAtIndex: kCPUProcessMenuIndex + ndx];
            mi.title = title;
            mi.image = icon;
            mi.hidden = NO;
        }
        else {
            [extraMenu itemAtIndex:kCPUProcessMenuIndex + ndx].hidden = YES;
        }
    }

    
	// Send the menu back to SystemUIServer
	return extraMenu;

} // menu

///////////////////////////////////////////////////////////////
//
//    NSMenuDelegate
//
///////////////////////////////////////////////////////////////

- (void)menuWillOpen:(NSMenu *)menu {
    
    if ([[NSUserDefaults standardUserDefaults] integerForKey:@"kCPUProcessCount"] > 0) {
        [cpuTopProcesses startUpdateProcessList];
    }
     
    [super menuWillOpen:menu];
    
} // menuWillOpen:

- (void)menuDidClose:(NSMenu *)menu {

    [cpuTopProcesses stopUpdateProcessList];

    [super menuDidClose:menu];

} // menuDidClose:

///////////////////////////////////////////////////////////////
//
//	Image renderers
//
///////////////////////////////////////////////////////////////

- (void)renderHistoryGraphIntoImage:(NSImage *)image forProcessor:(uint32_t)processor atOffset:(float)offset {

	// Construct paths
	NSBezierPath *systemPath =  [NSBezierPath bezierPath];
	NSBezierPath *userPath =  [NSBezierPath bezierPath];
	if (!(systemPath && userPath)) return;

	// Position for initial offset
	[systemPath moveToPoint:NSMakePoint(offset, 0)];
	[userPath moveToPoint:NSMakePoint(offset, 0)];

    int numberOfCPUs = [self numberOfCPUsToDisplay];

	// Loop over pixels in desired width until we're out of data
	int renderPosition = 0;
	float renderHeight = (float)[image size].height - 0.5f;  // Save space for baseline
	long cpuGraphLength = [[NSUserDefaults standardUserDefaults] integerForKey:@"kCPUGraphWidth"];
	for (renderPosition = 0; renderPosition < cpuGraphLength; renderPosition++) {
		// No data at this position?
		if (renderPosition >= [loadHistory count]) break;

		// Grab data
		NSArray *loadHistoryEntry = [loadHistory objectAtIndex:renderPosition];
		if (!loadHistoryEntry || ([loadHistoryEntry count] < numberOfCPUs)) {
			// Bad data, just skip
			continue;
		}

		// Get load at this position.
		MenuMeterCPULoad *load = loadHistoryEntry[processor];
		double system = load.system;
		double user = load.user;
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kCPUAvgAllProcs"]) {
			for (uint32_t cpuNum = 1; cpuNum < numberOfCPUs; cpuNum++) {
				MenuMeterCPULoad *load = loadHistoryEntry[cpuNum];
				system += load.system;
				user += load.user;
			}
			system /= numberOfCPUs;
			user /= numberOfCPUs;
		}
		// Sanity and limit
        system = CLAMP(system, 0, 1);
        user = CLAMP(user, 0, 1);

		// Update paths (adding baseline)
		[userPath lineToPoint:NSMakePoint(offset + renderPosition, 0.5f + MIN(system + user, 1) * renderHeight)];
		[systemPath lineToPoint:NSMakePoint(offset + renderPosition, (system * renderHeight) + 0.5f)];
	}

	// Return to lower edge (fill will close the graph)
	[userPath lineToPoint:NSMakePoint(offset + renderPosition - 1, 0)];
	[systemPath lineToPoint:NSMakePoint(offset + renderPosition - 1, 0)];

	// Draw
	[image lockFocus];
	[userColor set];
	[userPath fill];
	[systemColor set];
	[systemPath fill];

	// Clean up
	[[NSColor blackColor] set];
	[image unlockFocus];

} // renderHistoryGraphIntoImage:forProcessor:atOffset:

- (void)renderSinglePercentIntoImage:(NSImage *)image forProcessor:(uint32_t)processor atOffset:(float)offset {
    
    int numberOfCPUs = [self numberOfCPUsToDisplay];

	// Current load (if available)
	NSArray *currentLoad = [loadHistory lastObject];
	if (!currentLoad || ([currentLoad count] < numberOfCPUs)) return;

	MenuMeterCPULoad *load = currentLoad[processor];
	float totalLoad = load.system + load.user;
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kCPUAvgAllProcs"]) {
		for (uint32_t cpuNum = 1; cpuNum < numberOfCPUs; cpuNum++) {
			MenuMeterCPULoad *load = currentLoad[cpuNum];
			totalLoad += load.user + load.system;
		}
		totalLoad /= numberOfCPUs;
	}

    totalLoad = CLAMP(totalLoad, 0, 1);

	// Get the prerendered text and draw
	NSImage *percentImage = [singlePercentCache objectAtIndex:roundf(totalLoad * 100.0f)];
	if (!percentImage) return;
	[image lockFocus];
	if (1+[[NSUserDefaults standardUserDefaults] integerForKey:@"kCPUDisplayMode"] & kCPUDisplayGraph) {
		// When graphing right align, we had trouble with doing this with NSParagraphStyle, so do it manually
        [percentImage drawAtPoint:NSMakePoint(offset + percentWidth - ceilf((float)[percentImage size].width) - 1,
                                              (float)round(([image size].height - [percentImage size].height) / 2)
                                              )
                         fromRect:NSMakeRect(0, 0, [percentImage size].width, [percentImage size].height) operation:NSCompositeSourceOver fraction:1.0f];
	} else {
		// Otherwise center
        [percentImage drawAtPoint:NSMakePoint(offset + (float)floor(((percentWidth - [percentImage size].width) / 2)),
                                              (float)round(([image size].height - [percentImage size].height) / 2)
                                              )
                         fromRect:NSMakeRect(0, 0, [percentImage size].width, [percentImage size].height) operation:NSCompositeSourceOver fraction:1.0f];
	}
	[image unlockFocus];

}  // renderSinglePercentIntoImage:forProcessor:atOffset:

- (void)renderSplitPercentIntoImage:(NSImage *)image forProcessor:(uint32_t)processor atOffset:(float)offset {

    double system, user;
    [self getCPULoadForCPU:processor returnSystem:&system returnUser:&user];
    if ((system < 0) || (user < 0)) {
        return;
    }

	// Get the prerendered text and draw
	NSImage *systemImage = [splitSystemPercentCache objectAtIndex:roundf(system * 100.0f)];
	NSImage *userImage = [splitUserPercentCache objectAtIndex:roundf(user * 100.0f)];
	if (!(systemImage && userImage)) return;
	[image lockFocus];
	if (1+[[NSUserDefaults standardUserDefaults] integerForKey:@"kCPUDisplayMode"] & kCPUDisplayGraph) {
		// When graphing right align, we had trouble with doing this with NSParagraphStyle, so do it manually
        [systemImage drawAtPoint:NSMakePoint(offset + percentWidth - [systemImage size].width - 1, 0)
                        fromRect:NSMakeRect(0, 0, [systemImage size].width, [systemImage size].height) operation:NSCompositeSourceOver fraction:1.0f];
        [userImage drawAtPoint:NSMakePoint(offset + percentWidth - (float)[userImage size].width - 1,
                                           (float)floor([image size].height / 2))
                      fromRect:NSMakeRect(0, 0, [userImage size].width, [userImage size].height) operation:NSCompositeSourceOver fraction:1.0f];
	} else {
        [systemImage drawAtPoint:NSMakePoint(offset + floorf((percentWidth - (float)[systemImage size].width) / 2), 0)
                        fromRect:NSMakeRect(0, 0, [systemImage size].width, [systemImage size].height) operation:NSCompositeSourceOver fraction:1.0f];
        [userImage drawAtPoint:NSMakePoint(offset + floorf((percentWidth - (float)[systemImage size].width) / 2),
                                           (float)floor([image size].height / 2))
                      fromRect:NSMakeRect(0, 0, [userImage size].width, [userImage size].height) operation:NSCompositeSourceOver fraction:1.0f];
	}
	[image unlockFocus];

} // renderSplitPercentIntoImage:forProcessor:atOffset:

- (void)renderSingleTemperatureIntoImage:(NSImage *)image atOffset:(float)offset {
    float_t celsius = [cpuInfo cpuProximityTemperature];
    [image lockFocus];
    NSAttributedString *renderTemperatureString = [[NSAttributedString alloc]
         initWithString:[NSString stringWithFormat:@"%.1f°", celsius]
         attributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSFont systemFontOfSize:9.5f],
                     NSFontAttributeName, temperatureColor, NSForegroundColorAttributeName,
                     nil]];
    [renderTemperatureString drawAtPoint:NSMakePoint(
         kCPUTemperatureDisplayWidth - (float)round([renderTemperatureString size].width) - 1,
         (float)floor(([image size].height-[renderTemperatureString size].height) / 2)
    )];
    [image unlockFocus];
} // renderSingleTemperatureIntoImage:atOffset:


- (void)renderThermometerIntoImage:(NSImage *)image forProcessor:(uint32_t)processor atOffset:(float)offset {

    double system, user;
    [self getCPULoadForCPU:processor returnSystem:&system returnUser:&user];
    if ((system < 0) || (user < 0)) {
        return;
    }

	// Paths
	float thermometerTotalHeight = (float)[image size].height - 3.0f;
	NSBezierPath *userPath = [NSBezierPath bezierPathWithRect:NSMakeRect(offset + 1.5f, 1.5f, kCPUThermometerDisplayWidth - 3,
																		 thermometerTotalHeight * MIN(user + system, 1))];
	NSBezierPath *systemPath = [NSBezierPath bezierPathWithRect:NSMakeRect(offset + 1.5f, 1.5f, kCPUThermometerDisplayWidth - 3,
																		  thermometerTotalHeight * system)];
	NSBezierPath *framePath = [NSBezierPath bezierPathWithRect:NSMakeRect(offset + 1.5f, 1.5f, kCPUThermometerDisplayWidth - 3, thermometerTotalHeight)];

	// Draw
	[image lockFocus];
	[userColor set];
	[userPath fill];
	[systemColor set];
	[systemPath fill];
	[fgMenuThemeColor set];
	[framePath stroke];

	// Reset
	[[NSColor blackColor] set];
	[image unlockFocus];

} // renderThermometerIntoImage:forProcessor:atOffset:

- (void)renderHorizontalThermometerIntoImage:(NSImage *)image forProcessor:(uint32_t)processor atX:(float)x andY:(float)y withWidth:(float)width andHeight:(float)height {
    double system, user;
    [self getCPULoadForCPU:processor returnSystem:&system returnUser:&user];
    if ((system < 0) || (user < 0)) {
        return;
    }

	// Paths
    NSBezierPath *rightCapPath = [NSBezierPath bezierPathWithRect:NSMakeRect((x + width) - 2.0f, y, 1.0f, height - 1.0f)];

	NSBezierPath *userPath = [NSBezierPath bezierPathWithRect:NSMakeRect(x + 1.0f, y, (width - 2.0f) * MIN(user + system, 1), height - 1.0f)];

	NSBezierPath *systemPath = [NSBezierPath bezierPathWithRect:NSMakeRect(x + 1.0f, y, (width - 2.0f) * system, height - 1.0f)];

	// Draw
    [image lockFocus];
	[userColor set];
	[userPath fill];
	[systemColor set];
	[systemPath fill];
    [fgMenuThemeColor set];
    [rightCapPath fill];

	// Reset
	[[NSColor blackColor] set];
	[image unlockFocus];

} // renderHorizontalThermometerIntoImage:forProcessor:atX:andY:withWidth:andHeight:

///////////////////////////////////////////////////////////////
//
//	Timer callbacks
//
///////////////////////////////////////////////////////////////

- (void)timerFired:(NSTimer *)timerFired {
	// Get the current load
	NSArray *currentLoad = [cpuInfo currentLoadBySorting:[[NSUserDefaults standardUserDefaults] boolForKey:@"kCPUSortByUsage"]
                                    andCombineLowerHalf:[[NSUserDefaults standardUserDefaults] boolForKey:@"kCPUAvgLowerHalfProcs"]];
	if (!currentLoad) return;

	// Add to history (at least one)
	if (1+[[NSUserDefaults standardUserDefaults] integerForKey:@"kCPUDisplayMode"] & kCPUDisplayGraph) {
        long cpuGraphLength = [[NSUserDefaults standardUserDefaults] integerForKey:@"kCPUGraphWidth"];
		if ([loadHistory count] >= cpuGraphLength) {
			[loadHistory removeObjectsInRange:NSMakeRange(0, [loadHistory count] - cpuGraphLength + 1)];
		}
	} else {
		[loadHistory removeAllObjects];
	}
	[loadHistory addObject:currentLoad];

	// If the menu is down force it to update
	if (self.isMenuVisible) {
		[self updateMenuWhenDown];
	}

    [super timerFired:timerFired];
} // timerFired

- (void)updateMenuWhenDown {

	// Update content
	[self menu];

	// Force the menu to redraw
	LiveUpdateMenu(extraMenu);

} // updateMenuWhenDown

///////////////////////////////////////////////////////////////
//
//	Menu actions
//
///////////////////////////////////////////////////////////////

- (void)openProcessViewer:(id)sender {

	if (![[NSWorkspace sharedWorkspace] launchApplication:@"Process Viewer.app"]) {
		NSLog(@"MenuMeterCPU unable to launch the Process Viewer.");
	}

} // openProcessViewer

- (void)openActivityMonitor:(id)sender {

	if (![[NSWorkspace sharedWorkspace] launchApplication:@"Activity Monitor.app"]) {
		NSLog(@"MenuMeterCPU unable to launch the Activity Monitor.");
	}

} // openActivityMonitor

- (void)openConsole:(id)sender {

	if (![[NSWorkspace sharedWorkspace] launchApplication:@"Console.app"]) {
		NSLog(@"MenuMeterCPU unable to launch the Console.");
	}

} // openProcessViewer

///////////////////////////////////////////////////////////////
//
//	Prefs
//
///////////////////////////////////////////////////////////////

- (void)configFromPrefs:(NSNotification *)notification {
    [super configDisplay:[[NSUserDefaults standardUserDefaults] doubleForKey:@"kCPUMenuBundleID"]
       withTimerInterval:[[NSUserDefaults standardUserDefaults] doubleForKey:@"kCPUUpdateInterval"]];

	// Handle menubar theme changes
	fgMenuThemeColor = MenuItemTextColor();

	// Cache colors to skip archiver
    userColor = kCPUUserColorDefault;
    systemColor = kCPUSystemColorDefault;
    temperatureColor = kCPUTemperatureColorDefault;
    if ([[NSUserDefaults standardUserDefaults] dataForKey:@"kCPUUserColor"]) {
        userColor = [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] dataForKey:@"kCPUUserColor"]];
    }
    if ([[NSUserDefaults standardUserDefaults] dataForKey:@"kCPUSystemColor"]) {
        systemColor = [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] dataForKey:@"kCPUSystemColor"]];
    }
    if ([[NSUserDefaults standardUserDefaults] dataForKey:@"kCPUTemperatureColor"]) {
        temperatureColor = [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] dataForKey:@"kCPUTemperatureColor"]];
    }

	// It turns out that text drawing is _much_ slower than compositing images together
	// so we render several arrays of images, each representing a different percent value
	// which we can then composite together. Testing showed this to be almost 2x
	// faster than rendering the text every time through.
	singlePercentCache = nil;
	splitUserPercentCache = nil;
	splitSystemPercentCache = nil;

    long cpuPercentDisplay = [[NSUserDefaults standardUserDefaults] integerForKey:@"kCPUPercentDisplay"];
	if ((cpuPercentDisplay == kCPUPercentDisplayLarge) ||
		(cpuPercentDisplay == kCPUPercentDisplaySmall)) {

		singlePercentCache = [NSMutableArray array];
		float fontSize = 14;
		if (cpuPercentDisplay == kCPUPercentDisplaySmall) {
			fontSize = 11;
		}
		NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
											[NSFont systemFontOfSize:fontSize],
											NSFontAttributeName,
											fgMenuThemeColor,
											NSForegroundColorAttributeName,
											nil];
		for (int i = 0; i <= 100; i++) {
			NSAttributedString *cacheText = [[NSAttributedString alloc]
												initWithString:[NSString stringWithFormat:@"%d%%", i]
													attributes:textAttributes];
			NSImage *cacheImage = [[NSImage alloc] initWithSize:NSMakeSize(ceilf((float)[cacheText size].width),
																			ceilf((float)[cacheText size].height))];
			[cacheImage lockFocus];
			[cacheText drawAtPoint:NSMakePoint(0, 0)];
			[cacheImage unlockFocus];
			[singlePercentCache addObject:cacheImage];
		}
		// Calc the new width
		percentWidth = (float)round([[singlePercentCache lastObject] size].width) + kCPUPercentDisplayBorderWidth;
	} else if (cpuPercentDisplay == kCPUPercentDisplaySplit) {
		splitUserPercentCache = [NSMutableArray array];
		NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
											[NSFont systemFontOfSize:9.5f],
											NSFontAttributeName,
											userColor,
											NSForegroundColorAttributeName,
											nil];
		for (int i = 0; i <= 100; i++) {
			NSAttributedString *cacheText = [[NSAttributedString alloc]
												initWithString:[NSString stringWithFormat:@"%d%%", i]
													attributes:textAttributes];
			NSImage *cacheImage = [[NSImage alloc] initWithSize:NSMakeSize(ceilf((float)[cacheText size].width),
																			// No descenders, so render lower
																			[cacheText size].height - 1)];

			[cacheImage lockFocus];
			[cacheText drawAtPoint:NSMakePoint(0, -1)];  // No descenders in our text so render lower
			[cacheImage unlockFocus];
			[splitUserPercentCache addObject:cacheImage];
		}
		splitSystemPercentCache = [NSMutableArray array];
		textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
								[NSFont systemFontOfSize:9.5f],
								NSFontAttributeName,
								systemColor,
								NSForegroundColorAttributeName,
								nil];
		for (int i = 0; i <= 100; i++) {
			NSAttributedString *cacheText = [[NSAttributedString alloc]
											  initWithString:[NSString stringWithFormat:@"%d%%", i]
											  attributes:textAttributes];
			NSImage *cacheImage = [[NSImage alloc] initWithSize:NSMakeSize(ceilf((float)[cacheText size].width),
																			// No descenders, so render lower
																			[cacheText size].height - 1)];

			[cacheImage lockFocus];
			[cacheText drawAtPoint:NSMakePoint(0, -1)];  // No descenders in our text so render lower
			[cacheImage unlockFocus];
			[splitSystemPercentCache addObject:cacheImage];
		}
		// Calc the new text width, both arrays are same font, so use either
		percentWidth = (float)round([[splitSystemPercentCache lastObject] size].width) + kCPUPercentDisplayBorderWidth;
	}

	// Fix our menu size to match our new config
    int numberOfCPUs = [self numberOfCPUsToDisplay];
	menuWidth = 0;
    long mode = [[NSUserDefaults standardUserDefaults] integerForKey:@"kCPUDisplayMode"]+1;
    if (mode & kCPUDisplayHorizontalThermometer) {
        menuWidth = [[NSUserDefaults standardUserDefaults] integerForKey:@"kCPUHorizontalWidth"];
    }
    else {
        BOOL cpuAvgAllProcs = [[NSUserDefaults standardUserDefaults] boolForKey:@"kCPUAvgAllProcs"];
        if (mode & kCPUDisplayPercent) {
            menuWidth += ((cpuAvgAllProcs ? 1 : numberOfCPUs) * percentWidth);
        }
        if (mode & kCPUDisplayGraph) {
            menuWidth += ((cpuAvgAllProcs ? 1 : numberOfCPUs) * [[NSUserDefaults standardUserDefaults] integerForKey:@"kCPUGraphWidth"]);
        }
        if (mode & kCPUDisplayThermometer) {
            menuWidth += ((cpuAvgAllProcs ? 1 : numberOfCPUs) * kCPUThermometerDisplayWidth);
        }
        if (!cpuAvgAllProcs && (numberOfCPUs > 1)) {
            menuWidth += ((numberOfCPUs - 1) * kCPUDisplayMultiProcGapWidth);
        }
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kCPUShowTemperature"]) {
        menuWidth += kCPUTemperatureDisplayWidth;
    }

	// Resize the view
	[extraView setFrameSize:NSMakeSize(menuWidth, [extraView frame].size.height)];
	[self setLength:menuWidth];

	// Force initial update
	[self timerFired:nil];
} // configFromPrefs

- (uint32_t)numberOfCPUsToDisplay
{
    return [cpuInfo numberOfCPUsByCombiningLowerHalf:[[NSUserDefaults standardUserDefaults] boolForKey:@"kCPUAvgLowerHalfProcs"]];
}

- (void)getCPULoadForCPU:(uint32_t)processor
            returnSystem:(double *)system
              returnUser:(double *)user
{
	NSArray *currentLoad = [loadHistory lastObject];
	if (!currentLoad || ([currentLoad count] < processor)) {
        *system = -1;
        *user = -1;
        return;
    }

    [self getCPULoadFromLoad:currentLoad[processor]
                returnSystem:system
                  returnUser:user];
}

- (void)getCPULoadFromLoad:(MenuMeterCPULoad *)load
            returnSystem:(double *)system
              returnUser:(double *)user
{
    *system = CLAMP(load.system, 0, 1);
    *user = CLAMP(load.user, 0, 1);
}

@end
