//
//  MenuMeterSMCExtra.m
//  MenuMeters
//
//  Created by Roman Turchin on 5/15/19.
//

#import "MenuMeterSMCExtra.h"
#import "MenuMeterSMCConstants.h"
#import "smc_reader/smc_reader.h"

static NSDictionary* defaults;

NSColor     *temperatureCPUColor,
            *temperatureGPUColor,
            *powerCPUColor,
            *powerAllColor;

@implementation MenuMeterSMCExtra

-(NSDictionary*)defaults {
    if (!defaults) {
        //TODO: move to plist
        defaults = @{
                     @"kSMCMenuBundleID": @YES,

                     @"kSMCDisplayMode": [NSNumber numberWithInt:kSMCDisplaySmall],

                     @"kSMCUpdateIntervalMin": @0.5f,
                     @"kSMCUpdateIntervalMax": @10.0f,
                     @"kSMCUpdateInterval": @1.0f,

                     @"kSMCTemperatureCPU": @YES,
                     @"kSMCTemperatureGPU": @NO,
                     @"kSMCPowerCPU": @NO,
                     @"kSMCPowerAll": @YES,

                     @"kSMCTemperatureCPUColor": [NSArchiver archivedDataWithRootObject:kSMCTemperatureCPUColorDefault],
                     @"kSMCTemperatureGPUColor": [NSArchiver archivedDataWithRootObject:kSMCTemperatureGPUColorDefault],
                     @"kSMCPowerCPUColor": [NSArchiver archivedDataWithRootObject:kSMCPowerCPUColorDefault],
                     @"kSMCPowerAllColor": [NSArchiver archivedDataWithRootObject:kSMCPowerAllColorDefault],
                     };
    }
    return defaults;
}

-(id)getConfigPane {
    NSArray*viewObjects;
    [[NSBundle mainBundle] loadNibNamed:@"SMCPreferences" owner:self topLevelObjects:&viewObjects];
    for (id view in viewObjects) {
        if ([view isKindOfClass:[NSView class]]) {
            NSTabViewItem* prefView = [[NSTabViewItem alloc] init];
            [prefView setLabel:@"SMC"];
            [prefView setView:view];
            return prefView;
        }
    }
    return nil;
}

- (BOOL)enabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"kSMCMenuBundleID"];
}

- initWithBundle:(NSBundle *)bundle {

    self = [super initWithBundle:bundle];
    if (!self) {
        return nil;
    }

    extraMenu = [[NSMenu alloc] initWithTitle:@""];
    if (!extraMenu) {
        return nil;
    }
    [extraMenu setAutoenablesItems:NO];

    extraView = [[MenuMeterSMCView alloc] initWithFrame:[[self view] frame] menuExtra:self];
    if (!extraView) {
        return nil;
    }
    [self setView:extraView];

    [self configFromPrefs:nil];

    if (kIOReturnSuccess != SMCOpen()) {
        return nil;
    }
    NSLog(@"MenuMeterSMC loaded.");

    return self;

} // initWithBundle

-(void)willUnload {
    [super willUnload];
    SMCClose();
}

- (void)renderSingleNumberIntoImage:(NSImage *)image atPoint:(NSPoint)point withColor:(NSColor*)color {
    float_t celsius = 0.1f;
    [image lockFocus];
    NSAttributedString *renderTemperatureString = [[NSAttributedString alloc]
                                                   initWithString:[NSString stringWithFormat:@"%.1f°", celsius]
                                                   attributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSFont systemFontOfSize:9.5f],
                                                               NSFontAttributeName, color, NSForegroundColorAttributeName,
                                                               nil]];
    [renderTemperatureString drawAtPoint:point];
    [image unlockFocus];
}

- (void)configFromPrefs:(NSNotification *)notification {
    [super configDisplay:[[NSUserDefaults standardUserDefaults] boolForKey:@"kSMCMenuBundleID"]
       withTimerInterval:[[NSUserDefaults standardUserDefaults] floatForKey:@"kSMCUpdateInterval"]];

    // Resize the view
    [extraView setFrameSize:NSMakeSize(32.0, extraView.frame.size.height)];
    [self setLength:extraView.frame.size.width];

    temperatureCPUColor = kSMCTemperatureCPUColorDefault;
    temperatureGPUColor = kSMCTemperatureGPUColorDefault;
    powerCPUColor = kSMCPowerCPUColorDefault;
    powerAllColor = kSMCPowerAllColorDefault;
    if ([[NSUserDefaults standardUserDefaults] dataForKey:@"kSMCTemperatureCPUColor"]) {
        temperatureCPUColor = [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] dataForKey:@"kSMCTemperatureCPUColor"]];
    }
    if ([[NSUserDefaults standardUserDefaults] dataForKey:@"kSMCTemperatureGPUColor"]) {
        temperatureGPUColor = [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] dataForKey:@"kSMCTemperatureGPUColor"]];
    }
    if ([[NSUserDefaults standardUserDefaults] dataForKey:@"kSMCPowerCPUColor"]) {
        powerCPUColor = [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] dataForKey:@"kSMCPowerCPUColor"]];
    }
    if ([[NSUserDefaults standardUserDefaults] dataForKey:@"kSMCPowerAllColor"]) {
        powerAllColor = [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] dataForKey:@"kSMCPowerAllColor"]];
    }

    // Force initial update
    [self timerFired:nil];
} // configFromPrefs

- (NSImage *)image {

    NSImage *currentImage = [[NSImage alloc] initWithSize:NSMakeSize([extraView frame].size.width,
                                                                     [extraView frame].size.height - 1)];
    if (!currentImage) return nil;

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kSMCTemperatureCPU"]) {
        [currentImage lockFocus];
        NSAttributedString *renderString = [[NSAttributedString alloc]
                                            initWithString:[NSString stringWithFormat:@"%.1f℃", [self cpuProximityTemperature]]
                                                attributes:@{
                                                             NSFontAttributeName: [NSFont systemFontOfSize:9.5f],
                                                             NSForegroundColorAttributeName: temperatureCPUColor
                                                             }];
        [renderString drawAtPoint:NSMakePoint(
                                              currentImage.size.width-renderString.size.width,
                                              currentImage.size.height-renderString.size.height
                                              )];
        [currentImage unlockFocus];
    }

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kSMCPowerAll"]) {
        [currentImage lockFocus];
        NSAttributedString *renderString = [[NSAttributedString alloc]
                                            initWithString:[NSString stringWithFormat:@"%.1fW", [self allPower]]
                                                attributes:@{
                                                             NSFontAttributeName: [NSFont systemFontOfSize:9.5f],
                                                             NSForegroundColorAttributeName: powerAllColor
                                                             }];
        [renderString drawAtPoint:NSMakePoint(currentImage.size.width-renderString.size.width, 0.0)];
        [currentImage unlockFocus];
    }

    return currentImage;

} // image

- (float_t)cpuProximityTemperature {
    float_t celsius = -273.15F;
    SMCKeyValue value;
    if (kIOReturnSuccess == SMCReadKey(toSMCCode(SMC_CPU_TEMP), &value)) {
        celsius = UI16_TO_UINT32(value.bytes)/256.0f;
    }
    return celsius;
} // cpuProximityTemperature

- (float_t)allPower {
    float_t pwr = -0.1;
    SMCKeyValue value;
    if (kIOReturnSuccess == SMCReadKey(toSMCCode(SMC_ALL_POWER), &value)) {
        pwr = UI16_TO_UINT32(value.bytes)/256.0f;
    }
    return pwr;
} //


- (NSMenu *)menu {

    // Clear out the menu
    while ([extraMenu numberOfItems]) {
        [extraMenu removeItemAtIndex:0];
    }

    return extraMenu;

} // menu


@end
