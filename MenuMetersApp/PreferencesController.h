//
//  PreferencesController.h
//  MenuMeters
//
//  Created by Roman Turchin on 5/3/19.
//

#ifndef PreferencesController_h
#define PreferencesController_h

#import <SystemConfiguration/SystemConfiguration.h>



@interface PreferencesController : NSWindowController {
    // Main controls
    IBOutlet NSTabView               *prefTabs;

}

@end

#endif /* PreferencesController_h */
