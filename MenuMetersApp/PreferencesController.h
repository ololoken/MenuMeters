//
//  PreferencesController.h
//  MenuMeters
//
//  Created by Roman Turchin on 5/3/19.
//

#ifndef PreferencesController_h
#define PreferencesController_h

#import <SystemConfiguration/SystemConfiguration.h>
#import "MenuMeterDefaults.h"



@interface PreferencesController : NSWindowController {
    // Our preferences
    MenuMeterDefaults                *ourPrefs;
    // System config framework hooks
    SCDynamicStoreRef                scSession;
    CFRunLoopSourceRef               scRunSource;
    // Main controls
    IBOutlet NSTabView               *prefTabs;

    IBOutlet NSTabViewItem           *tabMem;
    IBOutlet NSTabViewItem           *tabDisk;
    IBOutlet NSTabViewItem           *tabNet;
    // Disk pane controls
    IBOutlet NSButton                *diskMeterToggle;
    IBOutlet NSPopUpButton           *diskImageSet;
    IBOutlet NSTextField             *diskIntervalDisplay;
    IBOutlet NSSlider                *diskInterval;
    IBOutlet NSPopUpButton           *diskSelectMode;
    // Mem pane controls
    IBOutlet NSButton                *memMeterToggle;
    IBOutlet NSPopUpButton           *memDisplayMode;
    IBOutlet NSTextField             *memIntervalDisplay;
    IBOutlet NSSlider                *memInterval;
    IBOutlet NSButton                *memFreeUsedLabeling;
    IBOutlet NSButton                *memPageIndicator;
    IBOutlet NSSlider                *memGraphWidth;
    IBOutlet NSTextField             *memGraphWidthLabel;
    IBOutlet NSTabView               *memColorTab;
    IBOutlet NSColorWell             *memActiveColor;
    IBOutlet NSColorWell             *memInactiveColor;
    IBOutlet NSColorWell             *memWiredColor;
    IBOutlet NSColorWell             *memCompressedColor;
    IBOutlet NSColorWell             *memFreeColor;
    IBOutlet NSColorWell             *memUsedColor;
    IBOutlet NSColorWell             *memPageinColor;
    IBOutlet NSTextField             *memPageinColorLabel;
    IBOutlet NSColorWell             *memPageoutColor;
    IBOutlet NSTextField             *memPageoutColorLabel;
    IBOutlet NSButton                *memPressureMode;
    // Net pane controls
    IBOutlet NSButton                *netMeterToggle;
    IBOutlet NSPopUpButton           *netDisplayMode;
    IBOutlet NSPopUpButton           *netDisplayOrientation;
    IBOutlet NSPopUpButton           *netPreferInterface;
    IBOutlet NSPopUpButton           *netScaleMode;
    IBOutlet NSTextField             *netScaleModeLabel;
    IBOutlet NSPopUpButton           *netScaleCalc;
    IBOutlet NSTextField             *netScaleCalcLabel;
    IBOutlet NSTextField             *netIntervalDisplay;
    IBOutlet NSSlider                *netInterval;
    IBOutlet NSButton                *netThroughputLabeling;
    IBOutlet NSButton                *netThroughput1KBound;
    IBOutlet NSPopUpButton           *netGraphStyle;
    IBOutlet NSTextField             *netGraphStyleLabel;
    IBOutlet NSSlider                *netGraphWidth;
    IBOutlet NSTextField             *netGraphWidthLabel;
    IBOutlet NSColorWell             *netTxColor;
    IBOutlet NSColorWell             *netRxColor;
    IBOutlet NSColorWell             *netInactiveColor;
    //SMC pane controls
    IBOutlet NSButton                *smcMeterToggle;
    IBOutlet NSTextField             *smcIntervalDisplay;
    IBOutlet NSSlider                *smcInterval;

} // MenuMetersPref

// IB Targets
- (IBAction)liveUpdateInterval:(id)sender;
- (IBAction)diskPrefChange:(id)sender;
- (IBAction)memPrefChange:(id)sender;
- (IBAction)netPrefChange:(id)sender;

- (bool)anyExtraMenuLoaded;

@end

#endif /* PreferencesController_h */
