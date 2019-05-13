//
//  MenuMeterDisk.h
//
// 	Constants and other definitions for the Disk Meter
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

///////////////////////////////////////////////////////////////
//
//	Constants
//
///////////////////////////////////////////////////////////////

// Bundle ID for the Disk menu extra
#define kDiskMenuBundleID                @"com.ragingmenace.MenuMeterDisk"

typedef enum {
	kDiskActivityIdle 			= 0,
	kDiskActivityRead,
	kDiskActivityWrite,
	kDiskActivityReadWrite
} DiskIOActivityType;

///////////////////////////////////////////////////////////////
//
//	Preference information
//
///////////////////////////////////////////////////////////////

#define kDiskArrowsImageSet				4
#define kDiskArrowsLargeImageSet		5

// Select mode constants
enum {
	kDiskSelectModeOpen					= 0,
	kDiskSelectModeEject
};
#define kDiskSelectModeDefault			kDiskSelectModeOpen

// View width, also menubar disk icon image width/height
#define kDiskViewWidth					16




