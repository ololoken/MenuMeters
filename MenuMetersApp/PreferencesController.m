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

// Menu extra manipulations
- (void)loadExtraAtURL:(NSURL *)extraURL withID:(NSString *)bundleID;
- (BOOL)isExtraWithBundleIDLoaded:(NSString *)bundleID;
- (void)removeExtraWithBundleID:(NSString *)bundleID;
- (void)showMenuExtraErrorSheet;

// Net configuration update
- (void)updateNetInterfaceMenu;

// CPU info
- (BOOL)isMultiProcessor;

// System config framework
- (void)connectSystemConfig;
- (void)disconnectSystemConfig;
- (NSDictionary *)sysconfigValueForKey:(NSString *)key;

@end

// Mem panel hidden tabs for color controls
enum {
    kMemActiveWiredInactiveColorTab = 0,
    kMemUsedFreeColorTab
};

///////////////////////////////////////////////////////////////
//
//    SystemConfiguration notification callbacks
//
///////////////////////////////////////////////////////////////

static void scChangeCallback(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info) {

    if (info) [(__bridge PreferencesController *)info updateNetInterfaceMenu];

} // scChangeCallback


@implementation PreferencesController

- (id)init {
    self = [super initWithWindowNibName:@"MenuMetersPreferencesWindow"];
    // Reread prefs on each load
    ourPrefs = [MenuMeterDefaults sharedMenuMeterDefaults];
    return self;
}

-(bool)anyExtraMenuLoaded {
    return [self isExtraWithBundleIDLoaded:kCPUMenuBundleID]
        || [self isExtraWithBundleIDLoaded:kMemMenuBundleID]
        || [self isExtraWithBundleIDLoaded:kDiskMenuBundleID]
        || [self isExtraWithBundleIDLoaded:kNetMenuBundleID];
}


-(IBAction)showWindow:(id)sender {
    [self willShow];
    [super showWindow:sender];
    [[self window] center];
    [[self window] makeKeyAndOrderFront:self];
    [NSApp activateIgnoringOtherApps:YES];
    if ([sender isKindOfClass:[MenuMeterCPUExtra class]]) {
        [prefTabs selectTabViewItem:tabCpu];
    }
    else if ([sender isKindOfClass:[MenuMeterDiskExtra class]]) {
        [prefTabs selectTabViewItem:tabDisk];
    }
    else if ([sender isKindOfClass:[MenuMeterMemExtra class]]) {
        [prefTabs selectTabViewItem:tabMem];
    }
    else if ([sender isKindOfClass:[MenuMeterNetExtra class]]) {
        [prefTabs selectTabViewItem:tabNet];
    }
}

///////////////////////////////////////////////////////////////
//
//    Pref pane standard methods
//
///////////////////////////////////////////////////////////////

- (void)windowDidLoad {
    // Set the switches on each menu toggle

    [cpuMeterToggle setState:([self isExtraWithBundleIDLoaded:kCPUMenuBundleID])];
    [diskMeterToggle setState:([self isExtraWithBundleIDLoaded:kDiskMenuBundleID])];
    [memMeterToggle setState:([self isExtraWithBundleIDLoaded:kMemMenuBundleID])];
    [netMeterToggle setState:([self isExtraWithBundleIDLoaded:kNetMenuBundleID])];

    [self cpuPrefChange:nil];
    [self diskPrefChange:nil];
    [self memPrefChange:nil];
    [self netPrefChange:nil];

    // Build the preferred interface menu and select (this actually updates the net prefs too)
    [self updateNetInterfaceMenu];

    // On first load populate the image set menu
    NSEnumerator *diskImageSetEnum = [kDiskImageSets objectEnumerator];
    [diskImageSet removeAllItems];
    NSString *imageSetName = nil;
    while ((imageSetName = [diskImageSetEnum nextObject])) {
        [diskImageSet addItemWithTitle:
         [[NSBundle bundleForClass:[self class]] localizedStringForKey:imageSetName value:nil table:nil]];
    }

    // On first load turn off cpu averaging control if this is not a multiproc machine
    [cpuAvgProcs setEnabled:[self isMultiProcessor]];

    // Set up a NSFormatter for use printing timers
    NSNumberFormatter *intervalFormatter = [[NSNumberFormatter alloc] init];
    [intervalFormatter setLocalizesFormat:YES];
    [intervalFormatter setFormat:@"###0.0"];

    [cpuIntervalDisplay setFormatter:intervalFormatter];
    [diskIntervalDisplay setFormatter:intervalFormatter];
    [netIntervalDisplay setFormatter:intervalFormatter];

    // Configure the scale menu to contain images and enough space
    [[netScaleCalc itemAtIndex:kNetScaleCalcLinear] setImage:[[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"LinearScale" ofType:@"tiff"]]];
    [[netScaleCalc itemAtIndex:kNetScaleCalcLinear] setTitle:[NSString stringWithFormat:@"  %@", [[netScaleCalc itemAtIndex:kNetScaleCalcLinear] title]]];
    [[netScaleCalc itemAtIndex:kNetScaleCalcSquareRoot] setImage:[[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SquareRootScale" ofType:@"tiff"]]];
    [[netScaleCalc itemAtIndex:kNetScaleCalcSquareRoot] setTitle:[NSString stringWithFormat:@"  %@", [[netScaleCalc itemAtIndex:kNetScaleCalcSquareRoot] title]]];
    [[netScaleCalc itemAtIndex:kNetScaleCalcCubeRoot] setImage:[[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"CubeRootScale" ofType:@"tiff"]]];
    [[netScaleCalc itemAtIndex:kNetScaleCalcCubeRoot] setTitle:[NSString stringWithFormat:@"  %@", [[netScaleCalc itemAtIndex:kNetScaleCalcCubeRoot] title]]];
    [[netScaleCalc itemAtIndex:kNetScaleCalcLog] setImage:[[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"LogScale" ofType:@"tiff"]]];
    [[netScaleCalc itemAtIndex:kNetScaleCalcLog] setTitle:[NSString stringWithFormat:@"  %@", [[netScaleCalc itemAtIndex:kNetScaleCalcLog] title]]];

} // mainViewDidLoad

- (void)willShow {

    // Hook up to SystemConfig Framework
    [self connectSystemConfig];

} // willShow

- (void)close {

    // Unregister all notifications
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self name:nil object:nil];

    // Unhook from SystemConfig Framework
    [self disconnectSystemConfig];

    [super close];

} // close

///////////////////////////////////////////////////////////////
//
//    IB Targets
//
///////////////////////////////////////////////////////////////
- (IBAction)liveUpdateInterval:(id)sender {
    if (sender == cpuInterval) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(cpuPrefChange:) object:cpuInterval];
        [self performSelector:@selector(cpuPrefChange:) withObject:cpuInterval afterDelay:0.0];
        [cpuIntervalDisplay takeDoubleValueFrom:cpuInterval];
    }
    else if (sender == diskInterval) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(diskPrefChange:) object:diskInterval];
        [self performSelector:@selector(diskPrefChange:) withObject:diskInterval afterDelay:0.0];
        [diskIntervalDisplay takeDoubleValueFrom:diskInterval];
    }
    else if (sender == memInterval) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(memPrefChange:) object:memInterval];
        [self performSelector:@selector(memPrefChange:) withObject:memInterval afterDelay:0.0];
        [memIntervalDisplay takeDoubleValueFrom:memInterval];
    }
    else if (sender == netInterval) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(netPrefChange:) object:netInterval];
        [self performSelector:@selector(netPrefChange:) withObject:netInterval afterDelay:0.0];
        [netIntervalDisplay takeDoubleValueFrom:netInterval];
    }
} // liveUpdateInterval:

- (void)toggleMenu:(NSButton *)toggle bundleID:(NSString *)bundleID {
    [toggle state]
        ? [self loadExtraWithId:bundleID]
        : [self removeExtraWithBundleID:bundleID];
    [toggle setState:[self isExtraWithBundleIDLoaded:bundleID]];
}

- (void)saveAndNotify:(NSString *)bundleID {
    // Write prefs and notify
    [ourPrefs syncWithDisk];
    if ([self isExtraWithBundleIDLoaded:bundleID]) {
        [[NSDistributedNotificationCenter defaultCenter]
         postNotificationName:bundleID
         object:kPrefChangeNotification
         userInfo:nil deliverImmediately:YES];
    }
}

- (IBAction)cpuPrefChange:(id)sender {

    // Extra load handler
    [self toggleMenu:cpuMeterToggle bundleID:kCPUMenuBundleID];

    // Save changes
    if (sender == cpuDisplayMode) {
        [ourPrefs saveCpuDisplayMode:(int)[cpuDisplayMode indexOfSelectedItem] + 1];
    } else if (sender == cpuTemperatureToggle) {
        [ourPrefs saveCpuTempreture:[cpuTemperatureToggle state]];
    } else if (sender == cpuInterval) {
        [ourPrefs saveCpuInterval:[cpuInterval doubleValue]];
    } else if (sender == cpuPercentMode) {
        [ourPrefs saveCpuPercentDisplay:(int)[cpuPercentMode indexOfSelectedItem]];
    } else if (sender == cpuMaxProcessCount) {
        [ourPrefs saveCpuMaxProcessCount:(int)[cpuMaxProcessCount intValue]];
    } else if (sender == cpuGraphWidth) {
        [ourPrefs saveCpuGraphLength:[cpuGraphWidth intValue]];
    } else if (sender == cpuHorizontalRows) {
        [ourPrefs saveCpuHorizontalRows:[cpuHorizontalRows intValue]];
    } else if (sender == cpuMenuWidth) {
        [ourPrefs saveCpuMenuWidth:[cpuMenuWidth intValue]];
    } else if (sender == cpuAvgProcs) {
        bool avg = [cpuAvgProcs state];
        [ourPrefs saveCpuAvgAllProcs:avg];
        if (avg) {
            [ourPrefs saveCpuAvgLowerHalfProcs:NO];
            [ourPrefs saveCpuSortByUsage:NO];
        }
    } else if (sender == cpuAvgLowerHalfProcs) {
        bool avg = [cpuAvgLowerHalfProcs state];
        [ourPrefs saveCpuAvgLowerHalfProcs:avg];
        if (avg) {
            [ourPrefs saveCpuAvgAllProcs:NO];
        }
    } else if (sender == cpuSortByUsage) {
        bool sort = [cpuSortByUsage state];
        [ourPrefs saveCpuSortByUsage:sort];
        if (sort) {
            [ourPrefs saveCpuAvgAllProcs:NO];
        }
        else {
            [ourPrefs saveCpuAvgLowerHalfProcs:NO];
        }
    } else if (sender == cpuUserColor) {
        [ourPrefs saveCpuUserColor:[cpuUserColor color]];
    } else if (sender == cpuSystemColor) {
        [ourPrefs saveCpuSystemColor:[cpuSystemColor color]];
    } else if (!sender) {
        // On first load handle multiprocs options
        if (![self isMultiProcessor]) {
            [ourPrefs saveCpuAvgAllProcs:NO];
        }
    }

    // Update controls
    [cpuDisplayMode selectItemAtIndex:-1]; // Work around multiselects. AppKit problem?
    [cpuDisplayMode selectItemAtIndex:[ourPrefs cpuDisplayMode] - 1];
    [cpuInterval setDoubleValue:[ourPrefs cpuInterval]];
    [cpuPercentMode selectItemAtIndex:-1]; // Work around multiselects. AppKit problem?
    [cpuPercentMode selectItemAtIndex:[ourPrefs cpuPercentDisplay]];
    [cpuMaxProcessCount setIntValue:[ourPrefs cpuMaxProcessCount]];
    [cpuMaxProcessCountCountLabel setStringValue:[NSString stringWithFormat:NSLocalizedString(@"(%d)", @"DO NOT LOCALIZE!!!"),
                                                  (short)[ourPrefs cpuMaxProcessCount]]];
    [cpuGraphWidth setIntValue:[ourPrefs cpuGraphLength]];
    [cpuHorizontalRows setIntValue:[ourPrefs cpuHorizontalRows]];
    [cpuMenuWidth setIntValue:[ourPrefs cpuMenuWidth]];
    [cpuAvgProcs setState:[ourPrefs cpuAvgAllProcs]];
    [cpuTemperatureToggle setState:[ourPrefs cpuShowTempreture]];
    [cpuAvgLowerHalfProcs setState:[ourPrefs cpuAvgLowerHalfProcs]];
    [cpuSortByUsage setState:[ourPrefs cpuSortByUsage]];
    [cpuUserColor setColor:[ourPrefs cpuUserColor]];
    [cpuSystemColor setColor:[ourPrefs cpuSystemColor]];
    [cpuTemperatureColor setColor:[ourPrefs cpuTemperatureColor]];
    [cpuIntervalDisplay takeDoubleValueFrom:cpuInterval];

    // Disable controls as needed
    if ([cpuSortByUsage state]) {
        [cpuAvgProcs setEnabled:NO];
        [cpuPercentModeLabel setTextColor:[NSColor lightGrayColor]];
        [cpuAvgLowerHalfProcs setEnabled:YES];
    }
    else {
        [cpuAvgProcs setEnabled:YES];
        [cpuPercentModeLabel setTextColor:[NSColor controlTextColor]];
        [cpuAvgLowerHalfProcs setEnabled:NO];
    }
    if ([cpuAvgProcs state]) {
        [cpuSortByUsage setEnabled:NO];
    }
    else {
        [cpuSortByUsage setEnabled:YES];
    }
    if (([cpuDisplayMode indexOfSelectedItem] + 1) & kCPUDisplayPercent) {
        [cpuPercentMode setEnabled:YES];
        [cpuPercentModeLabel setTextColor:[NSColor controlTextColor]];
    } else {
        [cpuPercentMode setEnabled:NO];
        [cpuPercentModeLabel setTextColor:[NSColor lightGrayColor]];
    }
    if (([cpuDisplayMode indexOfSelectedItem] + 1) & kCPUDisplayGraph) {
        [cpuGraphWidth setEnabled:YES];
        [cpuGraphWidthLabel setTextColor:[NSColor controlTextColor]];
    } else {
        [cpuGraphWidth setEnabled:NO];
        [cpuGraphWidthLabel setTextColor:[NSColor lightGrayColor]];
    }
    if (([cpuDisplayMode indexOfSelectedItem] + 1) & kCPUDisplayHorizontalThermometer) {
        [cpuHorizontalRows setEnabled:YES];
        [cpuHorizontalRowsLabel setTextColor:[NSColor controlTextColor]];
        [cpuMenuWidth setEnabled:YES];
        [cpuMenuWidthLabel setTextColor:[NSColor controlTextColor]];
        [cpuAvgProcs setEnabled:NO];
    }
    else {
        [cpuHorizontalRows setEnabled:NO];
        [cpuHorizontalRowsLabel setTextColor:[NSColor lightGrayColor]];
        [cpuMenuWidth setEnabled:NO];
        [cpuMenuWidthLabel setTextColor:[NSColor lightGrayColor]];
    }
    if ((([cpuDisplayMode indexOfSelectedItem] + 1) & (kCPUDisplayGraph | kCPUDisplayThermometer | kCPUDisplayHorizontalThermometer)) ||
        ((([cpuDisplayMode indexOfSelectedItem] + 1) & kCPUDisplayPercent) &&
         ([cpuPercentMode indexOfSelectedItem] == kCPUPercentDisplaySplit))) {
            [cpuUserColor setEnabled:YES];
            [cpuSystemColor setEnabled:YES];
            [cpuUserColorLabel setTextColor:[NSColor controlTextColor]];
            [cpuSystemColorLabel setTextColor:[NSColor controlTextColor]];
        } else {
            [cpuUserColor setEnabled:NO];
            [cpuSystemColor setEnabled:NO];
            [cpuUserColorLabel setTextColor:[NSColor lightGrayColor]];
            [cpuSystemColorLabel setTextColor:[NSColor lightGrayColor]];
        }

    [self saveAndNotify:kCPUMenuBundleID];

} // cpuPrefChange

- (IBAction)diskPrefChange:(id)sender {

    // Extra load
    [self toggleMenu:diskMeterToggle bundleID:kDiskMenuBundleID];

    // Save changes
    if (sender == diskImageSet) {
        [ourPrefs saveDiskImageset:(int)[diskImageSet indexOfSelectedItem]];
    } else if (sender == diskInterval) {
        [ourPrefs saveDiskInterval:[diskInterval doubleValue]];
    } else if (sender == diskSelectMode) {
        [ourPrefs saveDiskSelectMode:(int)[diskSelectMode indexOfSelectedItem]];
    }

    // Update controls
    [diskImageSet selectItemAtIndex:-1]; // Work around multiselects. AppKit problem?
    [diskImageSet selectItemAtIndex:[ourPrefs diskImageset]];
    [diskInterval setDoubleValue:[ourPrefs diskInterval]];
    [diskIntervalDisplay takeDoubleValueFrom:diskInterval];
    [diskSelectMode selectItemAtIndex:-1]; // Work around multiselects. AppKit problem?
    [diskSelectMode selectItemAtIndex:[ourPrefs diskSelectMode]];

    // Write prefs and notify
    [ourPrefs syncWithDisk];
    if ([self isExtraWithBundleIDLoaded:kDiskMenuBundleID]) {
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:kDiskMenuBundleID
                                                                       object:kPrefChangeNotification
                                                                     userInfo:nil deliverImmediately:YES];
    }

} // diskPrefChange

- (IBAction)memPrefChange:(id)sender {

    // Extra load
    [self toggleMenu:memMeterToggle bundleID:kMemMenuBundleID];

    // Save changes
    if (sender == memDisplayMode) {
        [ourPrefs saveMemDisplayMode:(int)[memDisplayMode indexOfSelectedItem] + 1];
    } else if (sender == memInterval) {
        [ourPrefs saveMemInterval:[memInterval doubleValue]];
    } else if (sender == memFreeUsedLabeling) {
        [ourPrefs saveMemUsedFreeLabel:[memFreeUsedLabeling state]];
    } else if (sender == memPageIndicator) {
        [ourPrefs saveMemPageIndicator:[memPageIndicator state]];
    } else if (sender == memPressureMode) {
        [ourPrefs saveMemPressure:[memPressureMode state]];
    } else if (sender == memGraphWidth) {
        [ourPrefs saveMemGraphLength:[memGraphWidth intValue]];
    } else if (sender == memActiveColor) {
        [ourPrefs saveMemActiveColor:[memActiveColor color]];
    } else if (sender == memInactiveColor) {
        [ourPrefs saveMemInactiveColor:[memInactiveColor color]];
    } else if (sender == memWiredColor) {
        [ourPrefs saveMemWireColor:[memWiredColor color]];
    } else if (sender == memCompressedColor) {
        [ourPrefs saveMemCompressedColor:[memCompressedColor color]];
    } else if (sender == memFreeColor) {
        [ourPrefs saveMemFreeColor:[memFreeColor color]];
    } else if (sender == memUsedColor) {
        [ourPrefs saveMemUsedColor:[memUsedColor color]];
    } else if (sender == memPageinColor) {
        [ourPrefs saveMemPageInColor:[memPageinColor color]];
    } else if (sender == memPageoutColor) {
        [ourPrefs saveMemPageOutColor:[memPageoutColor color]];
    }

    // Update controls
    [memDisplayMode selectItemAtIndex:-1]; // Work around multiselects. AppKit problem?
    [memDisplayMode selectItemAtIndex:[ourPrefs memDisplayMode] - 1];
    [memInterval setDoubleValue:[ourPrefs memInterval]];
    [memFreeUsedLabeling setState:[ourPrefs memUsedFreeLabel]];
    [memPageIndicator setState:[ourPrefs memPageIndicator]];
    [memPressureMode setState:[ourPrefs memPressure]];
    [memGraphWidth setIntValue:[ourPrefs memGraphLength]];
    [memActiveColor setColor:[ourPrefs memActiveColor]];
    [memInactiveColor setColor:[ourPrefs memInactiveColor]];
    [memWiredColor setColor:[ourPrefs memWireColor]];
    [memCompressedColor setColor:[ourPrefs memCompressedColor]];
    [memFreeColor setColor:[ourPrefs memFreeColor]];
    [memUsedColor setColor:[ourPrefs memUsedColor]];
    [memPageinColor setColor:[ourPrefs memPageInColor]];
    [memPageoutColor setColor:[ourPrefs memPageOutColor]];
    [memIntervalDisplay takeIntValueFrom:memInterval];

    // Disable controls as needed
    if ((([memDisplayMode indexOfSelectedItem] + 1) == kMemDisplayPie) ||
        (([memDisplayMode indexOfSelectedItem] + 1) == kMemDisplayBar) ||
        (([memDisplayMode indexOfSelectedItem] + 1) == kMemDisplayGraph)) {
        [memFreeUsedLabeling setEnabled:NO];
        [memColorTab selectTabViewItemAtIndex:kMemActiveWiredInactiveColorTab];
    } else {
        [memFreeUsedLabeling setEnabled:YES];
        [memColorTab selectTabViewItemAtIndex:kMemUsedFreeColorTab];
    }
    if (([memDisplayMode indexOfSelectedItem] + 1) == kMemDisplayGraph) {
        [memGraphWidth setEnabled:YES];
        [memGraphWidthLabel setTextColor:[NSColor controlTextColor]];
    } else {
        [memGraphWidth setEnabled:NO];
        [memGraphWidthLabel setTextColor:[NSColor lightGrayColor]];
    }
    if ([memPageIndicator state]) {
        [memPageinColorLabel setTextColor:[NSColor controlTextColor]];
        [memPageoutColorLabel setTextColor:[NSColor controlTextColor]];
        [memPageinColor setEnabled:YES];
        [memPageoutColor setEnabled:YES];
    } else {
        [memPageinColorLabel setTextColor:[NSColor lightGrayColor]];
        [memPageoutColorLabel setTextColor:[NSColor lightGrayColor]];
        [memPageinColor setEnabled:NO];
        [memPageoutColor setEnabled:NO];
    }
    if (([memDisplayMode indexOfSelectedItem] +1) == kMemDisplayBar) {
        [memPressureMode setEnabled:YES];
    }
    else {
        [memPressureMode setEnabled:NO];
    }

    [self saveAndNotify:kMemMenuBundleID];
} // memPrefChange

- (IBAction)netPrefChange:(id)sender {

    // Extra load
    [self toggleMenu:netMeterToggle bundleID:kNetMenuBundleID];

    // Save changes
    if (sender == netDisplayMode) {
        [ourPrefs saveNetDisplayMode:(int)[netDisplayMode indexOfSelectedItem] + 1];
    } else if (sender == netDisplayOrientation) {
        [ourPrefs saveNetDisplayOrientation:(int)[netDisplayOrientation indexOfSelectedItem]];
    } else if (sender == netScaleMode) {
        [ourPrefs saveNetScaleMode:(int)[netScaleMode indexOfSelectedItem]];
    } else if (sender == netScaleCalc) {
        [ourPrefs saveNetScaleCalc:(int)[netScaleCalc indexOfSelectedItem]];
    } else if (sender == netInterval) {
        [ourPrefs saveNetInterval:[netInterval doubleValue]];
    } else if (sender == netThroughputLabeling) {
        [ourPrefs saveNetThroughputLabel:[netThroughputLabeling state]];
    } else if (sender == netThroughput1KBound) {
        [ourPrefs saveNetThroughput1KBound:[netThroughput1KBound state]];
    } else if (sender == netGraphStyle) {
        [ourPrefs saveNetGraphStyle:(int)[netGraphStyle indexOfSelectedItem]];
    } else if (sender == netGraphWidth) {
        [ourPrefs saveNetGraphLength:[netGraphWidth intValue]];
    } else if (sender == netTxColor) {
        [ourPrefs saveNetTransmitColor:[netTxColor color]];
    } else if (sender == netRxColor) {
        [ourPrefs saveNetReceiveColor:[netRxColor color]];
    } else if (sender == netInactiveColor) {
        [ourPrefs saveNetInactiveColor:[netInactiveColor color]];
    } else if (sender == netPreferInterface) {
        NSMenuItem *menuItem = (NSMenuItem *)[netPreferInterface selectedItem];
        if (menuItem) {
            if (([netPreferInterface indexOfSelectedItem] == 0) || ![menuItem representedObject]) {
                [ourPrefs saveNetPreferInterface:kNetPrimaryInterface];
            } else {
                [ourPrefs saveNetPreferInterface:[menuItem representedObject]];
            }
        }
    }

    // Update controls
    [netDisplayMode selectItemAtIndex:-1]; // Work around multiselects. AppKit problem?
    [netDisplayMode selectItemAtIndex:[ourPrefs netDisplayMode] - 1];
    [netDisplayOrientation selectItemAtIndex:-1]; // Work around multiselects. AppKit problem?
    [netDisplayOrientation selectItemAtIndex:[ourPrefs netDisplayOrientation]];
    [netScaleMode selectItemAtIndex:-1]; // Work around multiselects. AppKit problem?
    [netScaleMode selectItemAtIndex:[ourPrefs netScaleMode]];
    [netScaleCalc selectItemAtIndex:-1]; // Work around multiselects. AppKit problem?
    [netScaleCalc selectItemAtIndex:[ourPrefs netScaleCalc]];
    [netInterval setDoubleValue:[ourPrefs netInterval]];
    [netThroughputLabeling setState:[ourPrefs netThroughputLabel]];
    [netThroughput1KBound setState:[ourPrefs netThroughput1KBound]];
    [netGraphStyle selectItemAtIndex:-1]; // Work around multiselects. AppKit problem?
    [netGraphStyle selectItemAtIndex:[ourPrefs netGraphStyle]];
    [netGraphWidth setIntValue:[ourPrefs netGraphLength]];
    [netTxColor setColor:[ourPrefs netTransmitColor]];
    [netRxColor setColor:[ourPrefs netReceiveColor]];
    [netInactiveColor setColor:[ourPrefs netInactiveColor]];
    [netIntervalDisplay takeDoubleValueFrom:netInterval];
    if ([[ourPrefs netPreferInterface] isEqualToString:kNetPrimaryInterface]) {
        [netPreferInterface selectItemAtIndex:0];
    } else {
        BOOL foundBetterItem = NO;
        NSArray *itemsArray = [netPreferInterface itemArray];
        if (itemsArray) {
            NSEnumerator *itemsEnum = [itemsArray objectEnumerator];
            NSMenuItem *menuItem = nil;
            while ((menuItem = [itemsEnum nextObject])) {
                if ([menuItem representedObject]) {
                    if ([[ourPrefs netPreferInterface] isEqualToString:[menuItem representedObject]]) {
                        [netPreferInterface selectItem:menuItem];
                        foundBetterItem = YES;
                    }
                }
            }
        }
        if (!foundBetterItem) {
            [netPreferInterface selectItemAtIndex:0];
            [ourPrefs saveNetPreferInterface:kNetPrimaryInterface];
        }
    }

    // Disable controls as needed
    if (([netDisplayMode indexOfSelectedItem] + 1) & kNetDisplayThroughput) {
        [netThroughputLabeling setEnabled:YES];
        [netThroughput1KBound setEnabled:YES];
    } else {
        [netThroughputLabeling setEnabled:NO];
        [netThroughput1KBound setEnabled:NO];
    }
    if (([netDisplayMode indexOfSelectedItem] + 1) & kNetDisplayGraph) {
        [netGraphStyle setEnabled:YES];
        [netGraphStyleLabel setTextColor:[NSColor controlTextColor]];
        [netGraphWidth setEnabled:YES];
        [netGraphWidthLabel setTextColor:[NSColor controlTextColor]];
    } else {
        [netGraphStyle setEnabled:NO];
        [netGraphStyleLabel setTextColor:[NSColor lightGrayColor]];
        [netGraphWidth setEnabled:NO];
        [netGraphWidthLabel setTextColor:[NSColor lightGrayColor]];
    }
    if ((([netDisplayMode indexOfSelectedItem] + 1) & kNetDisplayArrows) ||
        (([netDisplayMode indexOfSelectedItem] + 1) & kNetDisplayGraph)) {
        [netScaleMode setEnabled:YES];
        [netScaleModeLabel setTextColor:[NSColor controlTextColor]];
        [netScaleCalc setEnabled:YES];
        [netScaleCalcLabel setTextColor:[NSColor controlTextColor]];
    } else {
        [netScaleMode setEnabled:NO];
        [netScaleModeLabel setTextColor:[NSColor lightGrayColor]];
        [netScaleCalc setEnabled:NO];
        [netScaleCalcLabel setTextColor:[NSColor lightGrayColor]];
    }

    [self saveAndNotify:kNetMenuBundleID];
} // netPrefChange

///////////////////////////////////////////////////////////////
//
//    Menu extra manipulations
//
///////////////////////////////////////////////////////////////
- (BOOL)isExtraWithBundleIDLoaded:(NSString *)bundleID {
    return [ourPrefs loadBoolPref:bundleID defaultValue:YES];
} // isExtraWithBundleIDLoaded


- (void)loadExtraWithId:(NSString *)bundleID {
    if ([self isExtraWithBundleIDLoaded:bundleID]) {
        return;
    }
    [ourPrefs saveBoolPref:bundleID value:YES];
    [ourPrefs syncWithDisk];
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:bundleID
                                                                   object:kPrefChangeNotification
                                                                 userInfo:nil deliverImmediately:YES];
    return;
} // loadExtraAtURL:withID:

- (void)removeExtraWithBundleID:(NSString *)bundleID {
    if (![self isExtraWithBundleIDLoaded:bundleID]) {
        return;
    }
    [ourPrefs saveBoolPref:bundleID value:NO];
    [ourPrefs syncWithDisk];
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:bundleID
                                                                   object:kPrefChangeNotification
                                                                 userInfo:nil deliverImmediately:YES];
    return;
} // removeExtraWithBundleID

- (void)showMenuExtraErrorSheet {
    /*
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:[[NSBundle bundleForClass:[self class]]
                           localizedStringForKey:@"For instructions on enabling third-party menu extras please see the documentation."
                           value:nil
                           table:nil]];
    [alert setInformativeText:[[NSBundle bundleForClass:[self class]] localizedStringForKey:@"Menu Extra Could Not Load"
                                                                                      value:nil
                                                                                      table:nil]];
    [alert beginSheetModalForWindow:[[self mainView] window] completionHandler:^(NSModalResponse returnCode) {
        NSLog(@"Alert sheet ended");
    }];
     */
} // showMenuExtraErrorSheet

///////////////////////////////////////////////////////////////
//
//    Net prefs update
//
///////////////////////////////////////////////////////////////

- (void)updateNetInterfaceMenu {

    // Start by removing all items but the first
    while ([netPreferInterface numberOfItems] > 1) {
        [netPreferInterface removeItemAtIndex:[netPreferInterface numberOfItems] - 1];
    }

    // Now populate
    NSMenu *popupMenu = [netPreferInterface menu];
    if (!popupMenu) {
        [netPreferInterface selectItemAtIndex:0];
        [self netPrefChange:netPreferInterface];
        return;
    }

    // Get the dict block for services
    NSDictionary *ipDict = [self sysconfigValueForKey:@"Setup:/Network/Global/IPv4"];
    if (!ipDict) {
        [netPreferInterface selectItemAtIndex:0];
        [self netPrefChange:netPreferInterface];
        return;
    }
    // Get the array of services
    NSArray *serviceArray = [ipDict objectForKey:@"ServiceOrder"];
    if (!serviceArray) {
        [netPreferInterface selectItemAtIndex:0];
        [self netPrefChange:netPreferInterface];
        return;
    }

    NSEnumerator *serviceEnum = [serviceArray objectEnumerator];
    NSString *serviceID = nil;
    int    selectIndex = 0;
    while ((serviceID = [serviceEnum nextObject])) {
        NSString *longName = nil, *shortName = nil, *pppName = nil;
        // Get interface details
        NSDictionary *interfaceDict = [self sysconfigValueForKey:
                                       [NSString stringWithFormat:@"Setup:/Network/Service/%@/Interface", serviceID]];
        if (!interfaceDict) continue;
        // This code is a quasi-clone of the code in MenuMeterNetConfig.
        // Look there to see what all this means
        if ([interfaceDict objectForKey:@"UserDefinedName"]) {
            longName = [interfaceDict objectForKey:@"UserDefinedName"];
        } else if ([interfaceDict objectForKey:@"Hardware"]) {
            longName = [interfaceDict objectForKey:@"Hardware"];
        }
        if ([interfaceDict objectForKey:@"DeviceName"]) {
            shortName = [interfaceDict objectForKey:@"DeviceName"];
        }
        NSDictionary *pppDict = [self sysconfigValueForKey:
                                 [NSString stringWithFormat:@"State:/Network/Service/%@/PPP", serviceID]];
        if (pppDict && [pppDict objectForKey:@"InterfaceName"]) {
            pppName = [pppDict objectForKey:@"InterfaceName"];
        }
        // Now we can try to build the item
        if (!shortName) continue;  // Nothing to key off, bail
        if (!longName) longName = @"Unknown Interface";
        if (!shortName && pppName) {
            // Swap pppName for short name
            shortName = pppName;
            pppName = nil;
        }
        if (longName && shortName && pppName) {
            NSMenuItem *newMenuItem = (NSMenuItem *)[popupMenu addItemWithTitle:
                                                     [NSString stringWithFormat:@"%@ (%@, %@)", longName, shortName, pppName]
                                                                         action:nil
                                                                  keyEquivalent:@""];
            [newMenuItem setRepresentedObject:shortName];
            // Update the selected index if appropriate
            if ([shortName isEqualToString:[ourPrefs netPreferInterface]]) {
                selectIndex = (int)[popupMenu numberOfItems] - 1;
            }
        } else if (longName && shortName) {
            NSMenuItem *newMenuItem = (NSMenuItem *)[popupMenu addItemWithTitle:
                                                     [NSString stringWithFormat:@"%@ (%@)", longName, shortName]
                                                                         action:nil
                                                                  keyEquivalent:@""];
            [newMenuItem setRepresentedObject:shortName];
            // Update the selected index if appropriate
            if ([shortName isEqualToString:[ourPrefs netPreferInterface]]) {
                selectIndex = (int)[popupMenu numberOfItems] - 1;
            }
        }
    }

    // Menu is built, pick
    if ((selectIndex < 0) || (selectIndex >= [popupMenu numberOfItems])) {
        selectIndex = 0;
    }
    [netPreferInterface selectItemAtIndex:selectIndex];
    [self netPrefChange:netPreferInterface];
} // updateNetInterfaceMenu

///////////////////////////////////////////////////////////////
//
//    CPU info
//
///////////////////////////////////////////////////////////////

- (BOOL)isMultiProcessor {

    uint32_t cpuCount = 0;
    size_t sysctlLength = sizeof(cpuCount);
    int mib[2] = { CTL_HW, HW_NCPU };
    if (sysctl(mib, 2, &cpuCount, &sysctlLength, NULL, 0)) return NO;
    if (cpuCount > 1) {
        return YES;
    } else {
        return NO;
    }

} // isMultiProcessor

///////////////////////////////////////////////////////////////
//
//     System config framework
//
///////////////////////////////////////////////////////////////

- (void)connectSystemConfig {

    // Create the callback context
    SCDynamicStoreContext scContext;
    scContext.version = 0;
    scContext.info = (__bridge void * _Nullable)(self);
    scContext.retain = NULL;
    scContext.release = NULL;
    scContext.copyDescription = NULL;

    // And create the session, somewhat bizarrely, passing anything other than [self description]
    // cause an occassional crash in the callback.
    scSession = SCDynamicStoreCreate(kCFAllocatorDefault, (CFStringRef)[self description], scChangeCallback, &scContext);
    if (!scSession) {
        NSLog(@"MenuMetersPref unable to establish configd session.");
        return;
    }

    // Install notification run source
    if (!SCDynamicStoreSetNotificationKeys(scSession,
                                           (CFArrayRef)[NSArray arrayWithObjects:
                                                        @"State:/Network/Global/IPv4",
                                                        @"Setup:/Network/Global/IPv4",
                                                        @"State:/Network/Interface", nil],
                                           (CFArrayRef)[NSArray arrayWithObjects:
                                                        @"State:/Network/Interface.*", nil])) {
                                               NSLog(@"MenuMetersPref unable to install configd notification keys.");
                                               CFRelease(scSession);
                                               scSession = NULL;
                                               return;
                                           }
    scRunSource = SCDynamicStoreCreateRunLoopSource(kCFAllocatorDefault, scSession, 0);
    if (!scRunSource) {
        NSLog(@"MenuMetersPref unable to get configd notification keys run loop source.");
        CFRelease(scSession);
        scSession = NULL;
        return;
    }
    CFRunLoopAddSource(CFRunLoopGetCurrent(), scRunSource, kCFRunLoopDefaultMode);

} // connectSystemConfig

- (void)disconnectSystemConfig {

    // Remove the runsource
    if (scRunSource) {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), scRunSource, kCFRunLoopDefaultMode);
        CFRelease(scRunSource);
        scRunSource = NULL;
    }

    // Kill our configd session
    if (scSession) {
        CFRelease(scSession);
        scSession = NULL;
    }

} // disconnectSystemConfig

- (NSDictionary *)sysconfigValueForKey:(NSString *)key {

    if (!scSession) return nil;
    return (NSDictionary *)CFBridgingRelease(SCDynamicStoreCopyValue(scSession, (CFStringRef)key));

} // sysconfigValueForKey

@end
