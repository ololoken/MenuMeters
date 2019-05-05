//
//  AppDelegate.m
//  MenuMetersApp
//
//  Created by Yuji on 2015/07/30.
//
//

#import "AppDelegate.h"
#import "MenuMeterCPUExtra.h"
#import "MenuMeterDiskExtra.h"
#import "MenuMeterMemExtra.h"
#import "MenuMeterNetExtra.h"
#import "PreferencesController.h"

@interface AppDelegate ()

@end

@implementation AppDelegate
{
    PreferencesController *preferencesController;

    MenuMeterCPUExtra *cpuExtra;
    MenuMeterDiskExtra *diskExtra;
    MenuMeterNetExtra *netExtra;
    MenuMeterMemExtra *memExtra;

    NSTimer *timer;
}

//@synthesize preferences;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    cpuExtra = [[MenuMeterCPUExtra alloc] initWithBundle:[NSBundle mainBundle]];
    diskExtra = [[MenuMeterDiskExtra alloc] initWithBundle:[NSBundle mainBundle]];
    netExtra = [[MenuMeterNetExtra alloc] initWithBundle:[NSBundle mainBundle]];
    memExtra = [[MenuMeterMemExtra alloc] initWithBundle:[NSBundle mainBundle]];

    preferencesController = [[PreferencesController alloc] init];
}

- (void)showPreferences:(id)sender {
    [preferencesController showWindow:sender];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
