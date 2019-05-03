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
#import "EMCLoginItem.h"

///////////////////////////////////////////////////////////////
//
//    Private methods and constants
//
///////////////////////////////////////////////////////////////

@interface PreferencesController (PrivateMethods)

// Notifications
- (void)menuExtraUnloaded:(NSNotification *)notification;
- (void)menuExtraChangedPrefs:(NSNotification *)notification;

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

// MenuCracker
#define kMenuCrackerURL                [NSURL fileURLWithPath:[[self bundle] pathForResource:@"MenuCracker" ofType:@"menu" inDirectory:@""]]

// Paths to the menu extras
#define kCPUMenuURL nil
#define kDiskMenuURL nil
#define kMemMenuURL nil
#define kNetMenuURL nil

// How long to wait for Extras to add once CoreMenuExtraAddMenuExtra returns?
#define kWaitForExtraLoadMicroSec        10000000
#define kWaitForExtraLoadStepMicroSec    250000

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
    return self;
}

//this is a simple override of -showWindow: to ensure the window is always centered
-(IBAction)showWindow:(id)sender {
    [self willShow];
    [super showWindow:sender];
    [[self window] center];
}

///////////////////////////////////////////////////////////////
//
//    Pref pane standard methods
//
///////////////////////////////////////////////////////////////

- (void)windowDidLoad {

    // Check OS version
    BOOL isLeopardOrLater = OSIsLeopardOrLater();

    // Resize to be the new width of the System Preferences window for Leopard
    if (isLeopardOrLater) {
        //[[self mainView] setFrameSize:NSMakeSize(668, [[self mainView] frame].size.height)];
    }

    // On first load switch to the first tab
    [prefTabs selectFirstTabViewItem:self];

    // Set the switches on each menu toggle
    [cpuMeterToggle setState:([self extraWithBundleIDState:kCPUMenuBundleID])];
    [diskMeterToggle setState:([self extraWithBundleIDState:kDiskMenuBundleID])];
    [memMeterToggle setState:([self extraWithBundleIDState:kMemMenuBundleID])];
    [netMeterToggle setState:([self extraWithBundleIDState:kNetMenuBundleID])];

    // Reset the controls to match the prefs
    [self menuExtraChangedPrefs:nil];

    // Build the preferred interface menu and select (this actually updates the net prefs too)
    //[self updateNetInterfaceMenu];

    // On first load populate the image set menu
    NSEnumerator *diskImageSetEnum = [kDiskImageSets objectEnumerator];
    [diskImageSet removeAllItems];
    NSString *imageSetName = nil;
    while ((imageSetName = [diskImageSetEnum nextObject])) {
        [diskImageSet addItemWithTitle:
         [[NSBundle bundleForClass:[self class]]
          localizedStringForKey:imageSetName value:nil table:nil]];
    }

    // On first load set the version string with a clickable link
    //NSString*webpageURL=@"http://ragingmenace.com/";
    NSString* webpageURL=@"http://member.ipmu.jp/yuji.tachikawa/MenuMetersElCapitan/";
    NSMutableAttributedString *versionInfoString = [[[NSBundle bundleForClass:[self class]] infoDictionary] objectForKey:@"CFBundleGetInfoString"];
    NSMutableAttributedString *linkedVersionString = [[NSMutableAttributedString alloc] initWithString: [NSString stringWithFormat:@"%@ (%@)", versionInfoString,webpageURL]];
    [linkedVersionString beginEditing];
    [linkedVersionString setAlignment:NSCenterTextAlignment range:NSMakeRange(0, [linkedVersionString length])];
    [linkedVersionString addAttributes:
     [NSDictionary dictionaryWithObjectsAndKeys: [NSFont systemFontOfSize:10.0f], NSFontAttributeName, nil]
                                 range:NSMakeRange(0, [linkedVersionString length])];
    [linkedVersionString addAttributes:
     [NSDictionary dictionaryWithObjectsAndKeys: webpageURL,
        NSLinkAttributeName, [NSColor blueColor], NSForegroundColorAttributeName,
        [NSNumber numberWithInt:NSUnderlineStyleSingle], NSUnderlineStyleAttributeName, nil]
                                 range:NSMakeRange([versionInfoString length] + 2, [webpageURL length])];
    [linkedVersionString endEditing];
    // See QA1487
    [versionDisplay setAllowsEditingTextAttributes:YES];
    [versionDisplay setSelectable:YES];
    [versionDisplay setAttributedStringValue:linkedVersionString];

    // On first load turn off cpu averaging control if this is not a multiproc machine
    [cpuAvgProcs setEnabled:[self isMultiProcessor]];

    // Set up a NSFormatter for use printing timers
    NSNumberFormatter *intervalFormatter = [[NSNumberFormatter alloc] init];
    [intervalFormatter setLocalizesFormat:YES];
    [intervalFormatter setFormat:@"###0.0"];
    // Go through an archive/unarchive cycle to work around a bug on pre-10.2.2 systems
    // see http://cocoa.mamasam.com/COCOADEV/2001/12/2/21029.php
    intervalFormatter = [NSUnarchiver unarchiveObjectWithData:[NSArchiver archivedDataWithRootObject:intervalFormatter]];
    // Now set the formatters
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

    /*
    NSString *appPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"MenuMetersApp" ofType:@"app"];
    [[NSWorkspace sharedWorkspace] launchApplication:appPath];

    EMCLoginItem *loginItem = [EMCLoginItem loginItemWithPath:appPath];

    if (![loginItem isLoginItem])
    {
        [loginItem addLoginItem];
    }
     */
} // mainViewDidLoad

- (void)willShow {

    // Reread prefs on each load
    ourPrefs = [[MenuMeterDefaults alloc] init];

    // Hook up to SystemConfig Framework
    [self connectSystemConfig];

    // Register for pref change notifications from the extras
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(menuExtraChangedPrefs:)
                                                            name:kPrefPaneBundleID
                                                          object:kPrefChangeNotification];

    // Register for notifications from the extras when they unload
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(menuExtraUnloaded:)
                                                            name:kCPUMenuBundleID
                                                          object:kCPUMenuUnloadNotification];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(menuExtraUnloaded:)
                                                            name:kDiskMenuBundleID
                                                          object:kDiskMenuUnloadNotification];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(menuExtraUnloaded:)
                                                            name:kMemMenuBundleID
                                                          object:kMemMenuUnloadNotification];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(menuExtraUnloaded:)
                                                            name:kNetMenuBundleID
                                                          object:kNetMenuUnloadNotification];

} // willShow

- (void)close {

    // Unregister all notifications
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self name:nil object:nil];

    // Unhook from SystemConfig Framework
    [self disconnectSystemConfig];

    // Release prefs so it can reconnect next load
    ourPrefs = nil;

    [super close];

} // close

///////////////////////////////////////////////////////////////
//
//    Notifications
//
///////////////////////////////////////////////////////////////

- (void)menuExtraUnloaded:(NSNotification *)notification {

    NSString *bundleID = [notification name];
    if (bundleID) {
        if ([bundleID isEqualToString:kCPUMenuBundleID]) {
            [cpuMeterToggle setState:NSOffState];
        } else if ([bundleID isEqualToString:kDiskMenuBundleID]) {
            [diskMeterToggle setState:NSOffState];
        } else if ([bundleID isEqualToString:kMemMenuBundleID]) {
            [memMeterToggle setState:NSOffState];
        } else if ([bundleID isEqualToString:kNetMenuBundleID]) {
            [netMeterToggle setState:NSOffState];
        }
    }

} // menuExtraUnloaded

- (void)menuExtraChangedPrefs:(NSNotification *)notification {

    if (ourPrefs) {
        [ourPrefs syncWithDisk];
        [self cpuPrefChange:nil];
        [self diskPrefChange:nil];
        [self memPrefChange:nil];
        [self netPrefChange:nil];
    }

} // menuExtraChangedDefaults

///////////////////////////////////////////////////////////////
//
//    IB Targets
//
///////////////////////////////////////////////////////////////

- (IBAction)liveUpdateInterval:(id)sender {

    // Clever solution to live updating by exploiting the difference between
    // UI tracking and default runloop mode. See
    // http://www.cocoabuilder.com/archive/message/cocoa/2008/10/17/220399
    if (sender == cpuInterval) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                 selector:@selector(cpuPrefChange:)
                                                   object:cpuInterval];
        [self performSelector:@selector(cpuPrefChange:)
                   withObject:cpuInterval
                   afterDelay:0.0];
        [cpuIntervalDisplay takeDoubleValueFrom:cpuInterval];
    } else if (sender == diskInterval) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                 selector:@selector(diskPrefChange:)
                                                   object:diskInterval];
        [self performSelector:@selector(diskPrefChange:)
                   withObject:diskInterval
                   afterDelay:0.0];
        [diskIntervalDisplay takeDoubleValueFrom:diskInterval];
    } else if (sender == memInterval) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                 selector:@selector(memPrefChange:)
                                                   object:memInterval];
        [self performSelector:@selector(memPrefChange:)
                   withObject:memInterval
                   afterDelay:0.0];
        [memIntervalDisplay takeDoubleValueFrom:memInterval];
    } else if (sender == netInterval) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                 selector:@selector(netPrefChange:)
                                                   object:netInterval];
        [self performSelector:@selector(netPrefChange:)
                   withObject:netInterval
                   afterDelay:0.0];
        [netIntervalDisplay takeDoubleValueFrom:netInterval];
    }

} // liveUpdateInterval:

- (IBAction)cpuPrefChange:(id)sender {

    // Extra load handler
    if (([cpuMeterToggle state] == NSOnState) && ![self isExtraWithBundleIDLoaded:kCPUMenuBundleID]) {
        [self loadExtraAtURL:kCPUMenuURL withID:kCPUMenuBundleID];
    } else if (([cpuMeterToggle state] == NSOffState) && [self isExtraWithBundleIDLoaded:kCPUMenuBundleID]) {
        [self removeExtraWithBundleID:kCPUMenuBundleID];
    }
    [cpuMeterToggle setState:StateValue([self isExtraWithBundleIDLoaded:kCPUMenuBundleID])];

    // Save changes
    if (sender == cpuDisplayMode) {
        [ourPrefs saveCpuDisplayMode:(int)[cpuDisplayMode indexOfSelectedItem] + 1];
    } else if (sender == cpuTemperatureToggle) {
        bool show = [cpuTemperatureToggle state] == NSOnState ? YES : NO;
        [ourPrefs saveCpuTempreture:show];
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
        bool avg = ([cpuAvgProcs state] == NSOnState) ? YES : NO;
        [ourPrefs saveCpuAvgAllProcs:avg];
        if (avg) {
            [ourPrefs saveCpuAvgLowerHalfProcs:NO];
            [ourPrefs saveCpuSortByUsage:NO];
        }
    } else if (sender == cpuAvgLowerHalfProcs) {
        bool avg = ([cpuAvgLowerHalfProcs state] == NSOnState) ? YES : NO;
        [ourPrefs saveCpuAvgLowerHalfProcs:avg];
        if (avg) {
            [ourPrefs saveCpuAvgAllProcs:NO];
        }
    } else if (sender == cpuSortByUsage) {
        BOOL sort = ([cpuSortByUsage state] == NSOnState) ? YES : NO;
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
    [cpuAvgProcs setState:StateValue([ourPrefs cpuAvgAllProcs])];
    [cpuTemperatureToggle setState:StateValue([ourPrefs cpuShowTempreture])];
    [cpuAvgLowerHalfProcs setState:StateValue([ourPrefs cpuAvgLowerHalfProcs])];
    [cpuSortByUsage setState:StateValue([ourPrefs cpuSortByUsage])];
    [cpuUserColor setColor:[ourPrefs cpuUserColor]];
    [cpuSystemColor setColor:[ourPrefs cpuSystemColor]];
    [cpuTemperatureColor setColor:[ourPrefs cpuTemperatureColor]];
    [cpuIntervalDisplay takeDoubleValueFrom:cpuInterval];

    // Disable controls as needed
    if ([cpuSortByUsage state] == NSOnState) {
        [cpuAvgProcs setEnabled:NO];
        [cpuPercentModeLabel setTextColor:[NSColor lightGrayColor]];
        [cpuAvgLowerHalfProcs setEnabled:YES];
    }
    else {
        [cpuAvgProcs setEnabled:YES];
        [cpuPercentModeLabel setTextColor:[NSColor controlTextColor]];
        [cpuAvgLowerHalfProcs setEnabled:NO];
    }
    if ([cpuAvgProcs state] == NSOnState) {
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

    // Write prefs and notify
    [ourPrefs syncWithDisk];
    if ([self isExtraWithBundleIDLoaded:kCPUMenuBundleID]) {
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:kCPUMenuBundleID
                                                                       object:kPrefChangeNotification
                                                                     userInfo:nil deliverImmediately:YES];
    }

} // cpuPrefChange

- (IBAction)diskPrefChange:(id)sender {

    // Extra load
    if (([diskMeterToggle state] == NSOnState) && ![self isExtraWithBundleIDLoaded:kDiskMenuBundleID]) {
        [self loadExtraAtURL:kDiskMenuURL withID:kDiskMenuBundleID];
    } else if (([diskMeterToggle state] == NSOffState) && [self isExtraWithBundleIDLoaded:kDiskMenuBundleID]) {
        [self removeExtraWithBundleID:kDiskMenuBundleID];
    }
    [diskMeterToggle setState:([self isExtraWithBundleIDLoaded:kDiskMenuBundleID] ? NSOnState : NSOffState)];

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
    if (([memMeterToggle state] == NSOnState) && ![self isExtraWithBundleIDLoaded:kMemMenuBundleID]) {
        [self loadExtraAtURL:kMemMenuURL withID:kMemMenuBundleID];
    } else if (([memMeterToggle state] == NSOffState) && [self isExtraWithBundleIDLoaded:kMemMenuBundleID]) {
        [self removeExtraWithBundleID:kMemMenuBundleID];
    }
    [memMeterToggle setState:([self isExtraWithBundleIDLoaded:kMemMenuBundleID] ? NSOnState : NSOffState)];

    // Save changes
    if (sender == memDisplayMode) {
        [ourPrefs saveMemDisplayMode:(int)[memDisplayMode indexOfSelectedItem] + 1];
    } else if (sender == memInterval) {
        [ourPrefs saveMemInterval:[memInterval doubleValue]];
    } else if (sender == memFreeUsedLabeling) {
        [ourPrefs saveMemUsedFreeLabel:(([memFreeUsedLabeling state] == NSOnState) ? YES : NO)];
    } else if (sender == memPageIndicator) {
        [ourPrefs saveMemPageIndicator:(([memPageIndicator state] == NSOnState) ? YES : NO)];
    } else if (sender == memPressureMode) {
        [ourPrefs saveMemPressure:(([memPressureMode state] == NSOnState) ? YES : NO)];
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
    [memFreeUsedLabeling setState:([ourPrefs memUsedFreeLabel] ? NSOnState : NSOffState)];
    [memPageIndicator setState:([ourPrefs memPageIndicator] ? NSOnState : NSOffState)];
    [memPressureMode setState:([ourPrefs memPressure] ? NSOnState : NSOffState)];
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
    if ([memPageIndicator state] == NSOnState) {
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

    // Write prefs and notify
    [ourPrefs syncWithDisk];
    if ([self isExtraWithBundleIDLoaded:kMemMenuBundleID]) {
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:kMemMenuBundleID
                                                                       object:kPrefChangeNotification
                                                                     userInfo:nil deliverImmediately:YES];
    }

} // memPrefChange

- (IBAction)netPrefChange:(id)sender {

    // Extra load
    if (([netMeterToggle state] == NSOnState) && ![self isExtraWithBundleIDLoaded:kNetMenuBundleID]) {
        [self loadExtraAtURL:kNetMenuURL withID:kNetMenuBundleID];
    }
    else if (([netMeterToggle state] == NSOffState) && [self isExtraWithBundleIDLoaded:kNetMenuBundleID]) {
        [self removeExtraWithBundleID:kNetMenuBundleID];
    }
    [netMeterToggle setState:([self isExtraWithBundleIDLoaded:kNetMenuBundleID] ? NSOnState : NSOffState)];

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
        [ourPrefs saveNetThroughputLabel:(([netThroughputLabeling state] == NSOnState) ? YES : NO)];
    } else if (sender == netThroughput1KBound) {
        [ourPrefs saveNetThroughput1KBound:(([netThroughput1KBound state] == NSOnState) ? YES : NO)];
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
    [netThroughputLabeling setState:([ourPrefs netThroughputLabel] ? NSOnState : NSOffState)];
    [netThroughput1KBound setState:([ourPrefs netThroughput1KBound] ? NSOnState : NSOffState)];
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

    // Write prefs and notify
    [ourPrefs syncWithDisk];
    if ([self isExtraWithBundleIDLoaded:kNetMenuBundleID]) {
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:kNetMenuBundleID
                                                                       object:kPrefChangeNotification
                                                                     userInfo:nil deliverImmediately:YES];
    }

} // netPrefChange

///////////////////////////////////////////////////////////////
//
//    Menu extra manipulations
//
///////////////////////////////////////////////////////////////

- (void)loadExtraAtURL:(NSURL *)extraURL withID:(NSString *)bundleID {
    [ourPrefs saveBoolPref:bundleID value:YES];
    [ourPrefs syncWithDisk];
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:bundleID
                                                                   object:kPrefChangeNotification
                                                                 userInfo:nil deliverImmediately:YES];
    return;
} // loadExtraAtURL:withID:

- (BOOL)isExtraWithBundleIDLoaded:(NSString *)bundleID {
    return [ourPrefs loadBoolPref:bundleID defaultValue:YES];
} // isExtraWithBundleIDLoaded


- (NSControlStateValue)extraWithBundleIDState:(NSString *)bundleID {
    return [self isExtraWithBundleIDLoaded:bundleID]
        ? NSControlStateValueOn
        : NSControlStateValueOff;
} // isExtraWithBundleIDLoaded

- (void)removeExtraWithBundleID:(NSString *)bundleID {
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
