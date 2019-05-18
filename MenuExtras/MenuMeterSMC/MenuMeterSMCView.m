//
//  MenuMeterSMCView.m
//  MenuMeters
//
//  Created by Roman Turchin on 5/15/19.
//

#import "MenuMeterSMCView.h"

@implementation MenuMeterSMCView

- initWithFrame:(NSRect)rect menuExtra:extra {

    self = [super initWithFrame:rect];
    if (!self) {
        return nil;
    }
    smcMenuExtra = extra;
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {

    NSImage *image = [smcMenuExtra image];
    if (image) {
        if (smcMenuExtra.isMenuVisible) {
            [smcMenuExtra drawMenuBackground:YES];
        }
        [image drawAtPoint:NSMakePoint(0, 1) fromRect:NSMakeRect(0, 0, [image size].width, [image size].height) operation:NSCompositeSourceOver fraction:1.0f];
    }

}

@end
