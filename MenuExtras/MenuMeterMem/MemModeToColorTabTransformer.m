//
//  MemModeToColorTabTransformer.m
//  MenuMeters
//
//  Created by Roman Turchin on 5/13/19.
//

#import "MemModeToColorTabTransformer.h"
#import "MenuMeterMemConstants.h"

@implementation MemModeToColorTabTransformer
+ (BOOL)allowsReverseTransformation {
    return NO;
}

- (id)transformedValue:(NSNumber*)value {
    return [NSNumber numberWithInt:(
        value != nil
          ? ([value isEqualToNumber:@(kMemDisplayNumber)] ? 1 : 0)
          : 0
    )];
}

@end
