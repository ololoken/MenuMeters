//
//  PreferencesController.h
//  MenuMeters
//
//  Created by Roman Turchin on 5/3/19.
//

#ifndef PreferencesController_h
#define PreferencesController_h

#import <SystemConfiguration/SystemConfiguration.h>
#import "MenuMetersMenuExtraBase.h"

@interface PreferencesController : NSWindowController {
    // Main controls
    IBOutlet NSTabView               *prefTabs;

}

-(void)showWindowWithExtras:(id)sender extras:(NSMutableArray<MenuMetersMenuExtraBase*>*)extras;

@end

#endif /* PreferencesController_h */
