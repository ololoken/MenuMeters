//
//  MenuMeterCPUTopProcesses.mm
//
// 	Reader object for top CPU hogging process list
//
//  Copyright (c) 2018 Hofi
//
// 	This file is part of MenuMeters.
//
// 	MenuMeters is free software; you can redistribute it and/or modify
// 	it under the terms of the GNU General Public License version 2 as
//  published by the Free Software Foundation.
//
// 	MenuMeters is distributed in the hope that it will be useful,
// 	but WITHOUT ANY WARRANTY; without even the implied warranty of
// 	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// 	GNU General Public License for more details.
//
// 	You should have received a copy of the GNU General Public License
// 	along with MenuMeters; if not, write to the Free Software
// 	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//

#import "MenuMeterCPUTopProcesses.h"

///////////////////////////////////////////////////////////////
//
//    Process info item key strings
//
///////////////////////////////////////////////////////////////

#define PARTS_ARR_SIZE 5

NSString* const kProcessListItemPIDKey           = @"processID";
NSString* const kProcessListItemProcessNameKey   = @"processName";
NSString* const kProcessListItemProcessPathKey   = @"processPath";
NSString* const kProcessListItemUserIDKey        = @"userID";
NSString* const kProcessListItemUserNameKey      = @"userName";
NSString* const kProcessListItemCPUKey           = @"cpuPercent";

///////////////////////////////////////////////////////////////
//
//    Private categories
//
///////////////////////////////////////////////////////////////


///////////////////////////////////////////////////////////////
//
//	init/dealloc
//
///////////////////////////////////////////////////////////////

@implementation MenuMeterCPUTopProcesses
{
    NSMutableArray*psOutArray;
    NSTimer*psTimer;
}
    
-(instancetype)init
{
    self=[super init];
    psOutArray = [NSMutableArray array];
    return self;
}
- (void)startUpdateProcessList {
    if (psTimer != nil && psTimer.isValid) {
        [psTimer invalidate];
    }
    psTimer = [NSTimer timerWithTimeInterval:1.0 repeats:YES block:^(NSTimer*timer) {
        NSUInteger ranges[PARTS_ARR_SIZE];
        NSString*output = [self runCommand:[NSString stringWithFormat:@"/bin/ps -Ao pid=PID,pcpu=CPU,ruid=UID,ruser=USR,comm=CMD -rc | /usr/bin/head -%ld",
                                            [[NSUserDefaults standardUserDefaults] integerForKey:@"kCPUProcessCountMax"]]];
        NSArray*lines = [output componentsSeparatedByString:@"\n"];
        for (NSString*line in lines) {
            NSUInteger index = [lines indexOfObject:line];
            if (index == 0) {
                NSArray*parts = [line componentsSeparatedByString:@" "];
                NSUInteger count = 0;
                for (NSString*part in parts) {
                    if (![@"" isEqual:part]) {
                        ranges[count++] = NSMaxRange([line rangeOfString:part])+1;
                    }
                }
            }
            else if (line.length > 0) {
                NSDictionary*entry = @{ kProcessListItemPIDKey:[self prettyValueFrom:line at:NSMakeRange(0, ranges[0])],
                                        kProcessListItemCPUKey:[self prettyValueFrom:line at:NSMakeRange(ranges[0], ranges[1]-ranges[0])],
                                        kProcessListItemUserIDKey:[self prettyValueFrom:line at:NSMakeRange(ranges[1], ranges[2]-ranges[1])],
                                        kProcessListItemUserNameKey:[self prettyValueFrom:line at:NSMakeRange(ranges[2], ranges[3]-ranges[2]+1)],
                                        kProcessListItemProcessNameKey:[self prettyValueFrom:line at:NSMakeRange(ranges[3]+1, line.length-ranges[3]-1)] };
                self->psOutArray.count >= index
                    ? [self->psOutArray replaceObjectAtIndex:index-1 withObject:entry]
                    : [self->psOutArray insertObject:entry atIndex:index-1];
            }
        };
    }];
    [psTimer fire];
    [[NSRunLoop currentRunLoop] addTimer:psTimer forMode:NSRunLoopCommonModes];
} // startUpdateProcessList

- (NSString*)prettyValueFrom:(NSString *)line at:(NSRange) range {
    return [[line substringWithRange:range] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}
    
- (void)stopUpdateProcessList {
    [psTimer invalidate];
} // stopUpdateProcessList
    
- (NSArray *)runningProcessesByCPUUsage:(NSUInteger)maxItem {
    return [psOutArray subarrayWithRange:NSMakeRange(0, MIN(maxItem, psOutArray.count))];
}

- (NSString *)runCommand:(NSString *)commandToRun {
    NSPipe *pipe = [NSPipe pipe];
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/sh"];
    [task setArguments:[NSArray arrayWithObjects:@"-c", [NSString stringWithFormat:@"%@", commandToRun], nil]];
    [task setStandardOutput:pipe];
    [task launch];

    return [[NSString alloc] initWithData:[[pipe fileHandleForReading] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
}

@end
