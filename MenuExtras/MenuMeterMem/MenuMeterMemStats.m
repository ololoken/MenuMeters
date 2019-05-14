//
//  MenuMeterMemStats.m
//
// 	Reader object for VM info
//
//	Copyright (c) 2002-2014 Alex Harper
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

#import "MenuMeterMemStats.h"

///////////////////////////////////////////////////////////////
//
//	Definitions for 64-bit from 10.9+ so we can still use old SDKs.
//
///////////////////////////////////////////////////////////////
typedef kern_return_t (*host_statistics64_Ptr)(host_t host_priv,
											   host_flavor_t flavor,
											   host_info64_t host_info64_out,
											   mach_msg_type_number_t *host_info64_outCnt);
// host_statistics64 dynamic lookup
static host_statistics64_Ptr host_statistics64_Impl = NULL;

///////////////////////////////////////////////////////////////
//
//	Private methods and constants
//
///////////////////////////////////////////////////////////////

// Default strings for swap file login
#define kDefaultSwapPath		@"/private/var/vm/"
#define kDefaultSwapPrefix		@"swapfile"

@interface MenuMeterMemStats (PrivateMethods)
- (void)initializeSwapPath;
@end

@implementation MenuMeterMemStats

///////////////////////////////////////////////////////////////
//
//	Load
//
///////////////////////////////////////////////////////////////

+ (void)load {
	host_statistics64_Impl = dlsym(RTLD_DEFAULT, "host_statistics64");
}

///////////////////////////////////////////////////////////////
//
//	init/dealloc
//
///////////////////////////////////////////////////////////////

- (id)init {
	self = [super init];
	if (!self) {
		return nil;
	}

	// Build the Mach host reference
	selfHost = mach_host_self();
	if (!selfHost) {
		return nil;
	}

	// Paging indicator patch contributed by Bernhard Baehr.
	// Initialize lastpageins and lastpageouts
	[self memStats];

	return self;

} // init

 // dealloc


///////////////////////////////////////////////////////////////
//
//	 Mem usage info
//
///////////////////////////////////////////////////////////////
- (NSDictionary *)memStats64 {
	// Get the data using the 64-bit API.
	vm_statistics64_data_t vmStats64;
	bzero(&vmStats64, sizeof(vm_statistics64_data_t));
	// HOST_VM_INFO64_COUNT
	mach_msg_type_number_t vmCount = (mach_msg_type_number_t)(sizeof(vm_statistics64_data_t)/sizeof(integer_t));
	if (host_statistics64_Impl(selfHost, 4 /* HOST_VM_INFO64 */, (host_info64_t)&vmStats64, &vmCount) != KERN_SUCCESS) {
		return nil;
	}

	// Deltas, no concern about wraparound.
	uint64_t deltaPageIn = 0, deltaPageOut = 0;
	if (vmStats64.pageins >= lastPageIn) {
		deltaPageIn = vmStats64.pageins - lastPageIn;
	} else {
		deltaPageIn = vmStats64.pageins;
	}
	if (vmStats64.pageouts >= lastPageOut) {
		deltaPageOut = vmStats64.pageouts - lastPageOut;
	} else {
		deltaPageOut = vmStats64.pageouts;
	}
	// Update history
	lastPageIn = vmStats64.pageins;
	lastPageOut = vmStats64.pageouts;

	// Memory page statistics
	uint64_t active = vmStats64.active_count * vm_page_size;
	uint64_t inactive = vmStats64.inactive_count * vm_page_size;
	uint64_t wired = vmStats64.wire_count * vm_page_size;
	uint64_t free = vmStats64.free_count * vm_page_size;
	uint64_t compressed = vmStats64.compressor_page_count * vm_page_size;
	uint64_t uncompressed = vmStats64.total_uncompressed_pages_in_compressor * vm_page_size;

	// Update total
	totalRAM = active + inactive + wired + free + compressed;

  int system_memory_pressure;
  size_t length = sizeof(int);
  
  sysctlbyname("kern.memorystatus_vm_pressure_level", &system_memory_pressure, &length, nil, 0);
  
  double memory_pressure = system_memory_pressure * 0.25f;
  
	return [NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithDouble:(double)totalRAM / 1048576], @"totalmb",
				// See discussion in 32 bit code for historical difference between free/used.
				// By that standard compressed pages are probably active (OS compressing
				// rather than purging).
				[NSNumber numberWithDouble:(double)(free + inactive) / 1048576], @"freemb",
				[NSNumber numberWithDouble:(double)(active + wired  + compressed) / 1048576], @"usedmb",
				[NSNumber numberWithDouble:(double)active / 1048576], @"activemb",
				[NSNumber numberWithDouble:(double)inactive / 1048576], @"inactivemb",
				[NSNumber numberWithDouble:(double)wired / 1048576], @"wiremb",
				[NSNumber numberWithDouble:(double)free / 1048576], @"freepagemb",
				[NSNumber numberWithDouble:(double)compressed / 1048576], @"compressedmb",
				[NSNumber numberWithDouble:(double)uncompressed / 1048576], @"uncompressedmb",
				[NSNumber numberWithUnsignedLongLong:vmStats64.hits], @"hits",
				[NSNumber numberWithUnsignedLongLong:vmStats64.lookups], @"lookups",
				[NSNumber numberWithUnsignedLongLong:vmStats64.pageins], @"pageins",
				[NSNumber numberWithUnsignedLongLong:vmStats64.pageouts], @"pageouts",
				[NSNumber numberWithUnsignedLongLong:vmStats64.faults], @"faults",
				[NSNumber numberWithUnsignedLongLong:vmStats64.cow_faults], @"cowfaults",
				[NSNumber numberWithUnsignedLongLong:vmStats64.purges], @"purges",
				[NSNumber numberWithUnsignedLongLong:vmStats64.purgeable_count], @"purgeable_count",
				[NSNumber numberWithUnsignedLongLong:vmStats64.speculative_count], @"speculative_count",
				[NSNumber numberWithUnsignedLongLong:vmStats64.decompressions], @"decompressions",
				[NSNumber numberWithUnsignedLongLong:vmStats64.compressions], @"compressions",
				[NSNumber numberWithUnsignedLongLong:vmStats64.compressions], @"compressions",
				[NSNumber numberWithUnsignedLongLong:deltaPageIn], @"deltapageins",
				[NSNumber numberWithUnsignedLongLong:deltaPageOut], @"deltapageouts",
        [NSNumber numberWithDouble:(double)memory_pressure], @"mempress",
				nil];
} // memStats64

- (NSDictionary *)memStats {
    return [self memStats64];
} // memStats

- (NSDictionary *)swapStats {

	// Set up the swap path if its not already. We used to do this in the init,
	// but that occassionally crashed on load. So now we defer as much as possible
	if (!swapPath) {
		[self initializeSwapPath];
		if (!swapPath) return nil;
	}

	// Does the path exist? How many files?
	uint32_t swapCount = 0;
	uint64_t swapSize = 0;
	BOOL isDir = NO;
	NSFileManager *fm = [NSFileManager defaultManager];
	if ([fm fileExistsAtPath:swapPath isDirectory:&isDir] && isDir) {
		// Iterate the directory looking for swaps
		NSDirectoryEnumerator *dirEnum = [fm enumeratorAtPath:swapPath];
		NSString *currentFile = nil;
		while ((currentFile = [dirEnum nextObject])) {
			NSString *currentFileFullPath = [swapPath stringByAppendingPathComponent:currentFile];
			if ([currentFile hasPrefix:swapPrefix] &&
					[fm fileExistsAtPath:currentFileFullPath isDirectory:&isDir] &&
					!isDir) {
				swapCount++;
				swapSize += [[[fm attributesOfItemAtPath:currentFileFullPath
										  error:nil]
								objectForKey:NSFileSize] unsignedLongLongValue];
			}
		}
	}

	if (swapCount > peakSwapFiles) {
		peakSwapFiles = swapCount;
	}

	// On Tiger and later get swap usage and encryption, based on patch from
	// Michael Nordmeyer (http://goodyworks.com)
	BOOL encrypted = NO;
	uint64_t swapUsed = 0;
	if (isTigerOrLater) {
		int	swapMIB[] = { CTL_VM, 5 };
		struct xsw_usage swapUsage;
		size_t swapUsageSize = sizeof(swapUsage);
		memset(&swapUsage, 0, sizeof(swapUsage));
		if (sysctl(swapMIB, 2, &swapUsage, &swapUsageSize, NULL, 0) == 0) {
			encrypted = swapUsage.xsu_encrypted ? YES : NO;
			swapUsed = swapUsage.xsu_used;
		}
	}

	return [NSDictionary dictionaryWithObjectsAndKeys:
				swapPath, @"swappath",
				[NSNumber numberWithUnsignedInt:swapCount], @"swapcount",
				[NSNumber numberWithUnsignedInt:peakSwapFiles], @"swapcountpeak",
				[NSNumber numberWithUnsignedLongLong:swapSize / 1048576], @"swapsizemb",
				[NSNumber numberWithUnsignedLongLong:swapUsed / 1048576], @"swapusedmb",
				[NSNumber numberWithBool:encrypted], @"swapencrypted",
				nil];

} // swapStats

///////////////////////////////////////////////////////////////
//
//	Private methods
//
///////////////////////////////////////////////////////////////

- (void)initializeSwapPath {

	// We need to figure out where the swap file is. This information
	// is not published by dynamic_pager to sysctl. We can't get dynamic_pager's
	// arg list directed using sysctl because its UID 0. So we have to do some
	// parsing of ps -axww output to get the info.
	NSTask *psTask = [[NSTask alloc] init];
	[psTask setLaunchPath:@"/bin/ps"];
	[psTask setArguments:[NSArray arrayWithObjects:@"-axww", nil]];
	NSPipe *psPipe = [[NSPipe alloc] init];
	[psTask setStandardOutput:psPipe];
	NSFileHandle *psHandle = [psPipe fileHandleForReading];

	// Do the launch in an exception block. Old style block for 10.2 compatibility.
	// Accumulate all results into a single string for parse.
	NSMutableString *psOutput = [@"" mutableCopy];
	NSMutableString *swapFullPath = [NSMutableString string];
	BOOL taskLaunched = NO;
	NS_DURING
		[psTask launch];
		while ([psTask isRunning]) {
			[psOutput appendString:[[NSString alloc] initWithData:[psHandle availableData]
														   encoding:NSUTF8StringEncoding]];
			usleep(250000);
		}
	NS_HANDLER
		// Catch
		NSLog(@"MenuMeterMemStats unable to launch '/bin/ps'.");
		taskLaunched = NO;
		psOutput = nil;
	NS_ENDHANDLER
	if (psOutput) {
		NSArray *psSplit = [psOutput componentsSeparatedByString:@"\n"];
		NSEnumerator *psLineWalk = [psSplit objectEnumerator];
		NSString *psLine = nil;
		while ((psLine = [psLineWalk nextObject])) {
			NSArray *psArgSplit = [psLine componentsSeparatedByString:@" "];
			if (([psArgSplit containsObject:@"dynamic_pager"] || [psArgSplit containsObject:@"/sbin/dynamic_pager"]) &&
					[psArgSplit containsObject:@"-F"]) {
				// Consume all arguments till the next arg. This would fail
				// on the path "/my/silly -swappath/" but is that really something
				// we need to worry about?
				for (CFIndex argIndex = [psArgSplit indexOfObject:@"-F"] + 1; argIndex < [psArgSplit count]; argIndex++) {
					NSString *currentArg = [psArgSplit objectAtIndex:argIndex];
					if ([currentArg hasPrefix:@"-"]) break;
					if ([swapFullPath length]) [swapFullPath appendString:@" "];
					[swapFullPath appendString:currentArg];
				}
			}
			if (![swapFullPath isEqualToString:@""]) break;
		}
	}

	// Did we get it?
	if (![swapFullPath isEqualToString:@""]) {
		swapPath = [swapFullPath stringByDeletingLastPathComponent];
		swapPrefix = [swapFullPath lastPathComponent];
	}
	else {
		NSLog(@"MenuMeterMemStats unable to locate dynamic_pager args. Assume default.");
		swapPath = kDefaultSwapPath;
		swapPrefix = kDefaultSwapPrefix;
	}

} // initializeSwapPath

@end
