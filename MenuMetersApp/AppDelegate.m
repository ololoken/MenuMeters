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

static PreferencesController *preferencesController;

@implementation AppDelegate
{
    NSMutableArray<MenuMetersMenuExtraBase*> *extras;
}

//@synthesize preferences;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    bool needToShowPrefs = NO;
    extras = [[NSMutableArray alloc] init];

    NSArray* apps = [NSRunningApplication runningApplicationsWithBundleIdentifier:NSBundle.mainBundle.bundleIdentifier];
    if ([apps count] > 1) {
        for (NSRunningApplication *app in apps) {
            if (app.processIdentifier != NSProcessInfo.processInfo.processIdentifier) {
                [app terminate];
            }
        }
        needToShowPrefs = YES;
    }

    [extras addObject:[[MenuMeterCPUExtra alloc] initWithBundle:[NSBundle mainBundle]]];
    [extras addObject:[[MenuMeterMemExtra alloc] initWithBundle:[NSBundle mainBundle]]];
    [extras addObject:[[MenuMeterDiskExtra alloc] initWithBundle:[NSBundle mainBundle]]];
    [extras addObject:[[MenuMeterNetExtra alloc] initWithBundle:[NSBundle mainBundle]]];

    NSMutableDictionary*prefs = [[NSMutableDictionary alloc] init];
    for (MenuMetersMenuExtraBase*extra in extras) {
        [prefs addEntriesFromDictionary:[extra defaults]];
    }
    [[NSUserDefaults standardUserDefaults] registerDefaults:prefs];
    [[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:prefs];
    [[NSUserDefaultsController sharedUserDefaultsController] setAppliesImmediately:YES];

    BOOL nothingLoaded = YES;
    for (MenuMetersMenuExtraBase*extra in extras) {
        if ([extra enabled]) {
            nothingLoaded = NO;
            break;
        }
    }
    if (needToShowPrefs || nothingLoaded) {
        [self showPreferences:nil];
    }
}

- (void)showPreferences:(id)sender {
    if (!preferencesController) {
        preferencesController = [[PreferencesController alloc] init];
    }
    [preferencesController showWindowWithExtras:sender extras:extras];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
