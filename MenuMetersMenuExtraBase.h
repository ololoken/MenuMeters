//
//  NSMenuExtraBase.h
//  MenuMeters
//
//  Created by Yuji on 2015/08/01.
//
//
#define kMenuIndentFormat                  @"    %@"
#define kMenuDoubleIndentFormat            @"        %@"
#define kMenuTripleIndentFormat            @"            %@"

#import <Foundation/Foundation.h>
#import "AppleUndocumented.h"

@interface MenuMetersMenuExtraBase : NSMenuExtra <NSMenuDelegate>
{
    NSStatusItem* statusItem;
    NSTimer* updateTimer;
}
- (void)configDisplay:(BOOL)enabled withTimerInterval:(NSTimeInterval)interval;
- (void)timerFired:(id)timer;

@property(nonatomic, readonly) BOOL isMenuVisible;

- (id)getConfigPane;
- (BOOL)enabled;
- (void)configFromPrefs:(id)sender;
- (NSDictionary*)defaults;
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context;

@end

#define NSMenuExtra MenuMetersMenuExtraBase
