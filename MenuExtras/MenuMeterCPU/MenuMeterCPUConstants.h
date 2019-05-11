//
//  MenuMeterCPU.h
//
// 	Constants and other definitions for the CPU Meter
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
#define kCPUMenuBundleID                @"com.ragingmenace.MenuMeterCPU"

// Widths of the various displays
#define kCPUPercentDisplayBorderWidth		2
#define kCPUThermometerDisplayWidth			10
#define kCPUDisplayMultiProcGapWidth		5
#define kCPUTemperatureDisplayWidth         26

// Menu item indexes
#define kCPUUptimeInfoMenuIndex				3
#define kCPUTaskInfoMenuIndex				5
#define kCPULoadInfoMenuIndex				7
#define kCPUProcessLabelMenuIndex           8
#define kCPUProcessMenuIndex                kCPUProcessLabelMenuIndex+1

///////////////////////////////////////////////////////////////
//
//	Preference information
//
///////////////////////////////////////////////////////////////

// Display modes
enum {
	kCPUDisplayPercent						= 1,
	kCPUDisplayGraph						= 2,
	kCPUDisplayThermometer					= 4,
    kCPUDisplayHorizontalThermometer        = 8
};
#define kCPUDisplayDefault					kCPUDisplayPercent

// Percent display modes
enum {
	kCPUPercentDisplayLarge					= 0,
	kCPUPercentDisplaySmall,
	kCPUPercentDisplaySplit
};
#define kCPUPercentDisplayDefault			kCPUPercentDisplaySmall

// Colors
											// Maraschino
#define kCPUSystemColorDefault				[NSColor colorWithDeviceRed:1.0f green:0.0f blue:0.0f alpha:1.0f]
											// Midnight blue
#define kCPUUserColorDefault				[NSColor colorWithDeviceRed:0.0f green:0.0f blue:0.5f alpha:1.0f]
                                            // Orange
#define kCPUTemperatureColorDefault         [NSColor colorWithDeviceRed:1.0f green:0.647f blue:0.0f alpha:1.0f]





