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
}

//@synthesize preferences;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    bool needToShowPrefs = NO;
    NSArray* apps = [NSRunningApplication runningApplicationsWithBundleIdentifier:NSBundle.mainBundle.bundleIdentifier];
    if ([apps count] > 1) {
        for (NSRunningApplication *app in apps) {
            if (app.processIdentifier != NSProcessInfo.processInfo.processIdentifier) {
                [app terminate];
            }
        }
        needToShowPrefs = YES;
    }

    cpuExtra = [[MenuMeterCPUExtra alloc] initWithBundle:[NSBundle mainBundle]];
    diskExtra = [[MenuMeterDiskExtra alloc] initWithBundle:[NSBundle mainBundle]];
    netExtra = [[MenuMeterNetExtra alloc] initWithBundle:[NSBundle mainBundle]];
    memExtra = [[MenuMeterMemExtra alloc] initWithBundle:[NSBundle mainBundle]];

    NSMutableDictionary*prefs = [[NSMutableDictionary alloc] init];
    [prefs addEntriesFromDictionary:[cpuExtra defaults]];
    [prefs addEntriesFromDictionary:[diskExtra defaults]];
    [prefs addEntriesFromDictionary:[memExtra defaults]];
    [prefs addEntriesFromDictionary:[netExtra defaults]];
    [[NSUserDefaults standardUserDefaults] registerDefaults:prefs];
    [[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:prefs];
    [[NSUserDefaultsController sharedUserDefaultsController] setAppliesImmediately:YES];

    preferencesController = [[PreferencesController alloc] init];

    BOOL nothingLoaded = ![[NSUserDefaults standardUserDefaults] boolForKey:@"kNetMenuBundleID"]
        && ![[NSUserDefaults standardUserDefaults] boolForKey:@"kMemMenuBundleID"]
        && ![[NSUserDefaults standardUserDefaults] boolForKey:@"kCPUMenuBundleID"]
        && ![[NSUserDefaults standardUserDefaults] boolForKey:@"kDiskMenuBundleID"];
    if (needToShowPrefs || nothingLoaded) {
        [self showPreferences:nil];
    }
}

- (void)showPreferences:(id)sender {
    [preferencesController showWindow:sender];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
