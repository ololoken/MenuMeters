//
//	MenuMeterDefaults.m
//
//	Preference (defaults) file reader/writer
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

#import "MenuMeterDefaults.h"
#import "MenuMeterMemConstants.h"
#import "MenuMeterNet.h"


///////////////////////////////////////////////////////////////
//
//	Private
//
///////////////////////////////////////////////////////////////

@interface MenuMeterDefaults (PrivateMethods)

// Prefs version migration
- (void)migratePrefFile;
- (void)migratePrefsForward;

// Datatype read/write
- (double)loadDoublePref:(NSString *)prefName lowBound:(double)lowBound highBound:(double)highBound defaultValue:(double)defaultValue;
- (void)saveDoublePref:(NSString *)prefName value:(double)value;
- (int)loadIntPref:(NSString *)prefName lowBound:(int)lowBound highBound:(int)highBound defaultValue:(int)defaultValue;
- (void)saveIntPref:(NSString *)prefName value:(int)value;
- (int)loadBitFlagPref:(NSString *)prefName validFlags:(int)flags zeroValid:(BOOL)zeroValid defaultValue:(int)defaultValue;
- (void)saveBitFlagPref:(NSString *)prefName value:(int)value;
- (NSColor *)loadColorPref:(NSString *)prefName defaultValue:(NSColor *)defaultValue;
- (void)saveColorPref:(NSString *)prefname value:(NSColor *)value;
- (NSString *)loadStringPref:(NSString *)prefName defaultValue:(NSString *)defaultValue;
- (void)saveStringPref:(NSString *)prefName value:(NSString *)value;

@end

///////////////////////////////////////////////////////////////
//
//	init/dealloc
//
///////////////////////////////////////////////////////////////

@implementation MenuMeterDefaults

+ (MenuMeterDefaults*)sharedMenuMeterDefaults {
    static MenuMeterDefaults *foo = nil;
    if(!foo){
        foo=[[MenuMeterDefaults alloc] init];
    }
    return foo;
}
- (id)init {

	// Allow super to init
	self = [super init];
	if (!self) {
		return nil;
	}

	// Move the pref file if we need to
	[self migratePrefFile];

	// Load pref values
	[self syncWithDisk];

	// Do migration
	[self migratePrefsForward];

	// Send on back
	return self;

} // init

- (void)dealloc {

	// Save back
	[self syncWithDisk];

	// Super do its thing

} // dealloc

///////////////////////////////////////////////////////////////
//
//	Pref read/write
//
///////////////////////////////////////////////////////////////

- (void)syncWithDisk {

	CFPreferencesSynchronize((CFStringRef)kMenuMeterDefaultsDomain,
							 kCFPreferencesCurrentUser, kCFPreferencesAnyHost);

} // syncFromDisk

///////////////////////////////////////////////////////////////
//
//	Mem menu prefs
//
///////////////////////////////////////////////////////////////

- (double)memInterval {
	return [self loadDoublePref:kMemIntervalPref
					   lowBound:kMemUpdateIntervalMin
					  highBound:kMemUpdateIntervalMax
				   defaultValue:kMemUpdateIntervalDefault];
} // memInterval

- (int)memDisplayMode {
	return [self loadIntPref:kMemDisplayModePref
					lowBound:kMemDisplayPie
				   highBound:kMemDisplayNumber
				defaultValue:kMemDisplayDefault];
} // memDisplayMode

- (BOOL)memPageIndicator {
	return [self loadBoolPref:kMemPageIndicatorPref defaultValue:kMemPageIndicatorDefault];
} // memPageIndicator

- (BOOL)memUsedFreeLabel {
	return [self loadBoolPref:kMemUsedFreeLabelPref defaultValue:kMemUsedFreeLabelDefault];
} // memUsedFreeLabel

- (BOOL)memPressure {
  return [self loadBoolPref:kMemPressurePref defaultValue:kMemPressureDefault];
} // memUsedFreeLabel

- (int)memGraphLength {
	return [self loadIntPref:kMemGraphLengthPref
					lowBound:kMemGraphWidthMin
				   highBound:kMemGraphWidthMax
				defaultValue:kMemGraphWidthDefault];
} // memGraphLength

- (NSColor *)memFreeColor {
	return [self loadColorPref:kMemFreeColorPref defaultValue:kMemFreeColorDefault];
} // memFreeColor

- (NSColor *)memUsedColor {
	return [self loadColorPref:kMemUsedColorPref defaultValue:kMemUsedColorDefault];
} // memUsedColor

- (NSColor *)memActiveColor {
	return [self loadColorPref:kMemActiveColorPref defaultValue:kMemActiveColorDefault];
} // memActiveColor

- (NSColor *)memInactiveColor {
	return [self loadColorPref:kMemInactiveColorPref defaultValue:kMemInactiveColorDefault];
} // memInactiveColor

- (NSColor *)memWireColor {
	return [self loadColorPref:kMemWireColorPref defaultValue:kMemWireColorDefault];
} // memWireColor

- (NSColor *)memCompressedColor {
	return [self loadColorPref:kMemCompressedColorPref defaultValue:kMemCompressedColorDefault];
} // memCompressedColor

- (NSColor *)memPageInColor {
	return [self loadColorPref:kMemPageInColorPref defaultValue:kMemPageInColorDefault];
} // memPageinColor

- (NSColor *)memPageOutColor {
	return [self loadColorPref:kMemPageOutColorPref defaultValue:kMemPageOutColorDefault];
} // memPageoutColor

- (void)saveMemInterval:(double)interval {
	[self saveDoublePref:kMemIntervalPref value:interval];
} // saveMemInterval

- (void)saveMemDisplayMode:(int)mode {
	[self saveIntPref:kMemDisplayModePref value:mode];
} // saveMemDisplayMode

- (void)saveMemUsedFreeLabel:(BOOL)label {
	[self saveBoolPref:kMemUsedFreeLabelPref value:label];
} // saveMemUsedFreeLabel

- (void)saveMemPressure:(BOOL)label {
  [self saveBoolPref:kMemPressurePref value:label];
} // saveMemPressure

- (void)saveMemPageIndicator:(BOOL)indicator {
	[self saveBoolPref:kMemPageIndicatorPref value:indicator];
} // saveMemPageIndicator

- (void)saveMemGraphLength:(int)length {
	[self saveIntPref:kMemGraphLengthPref value:length];
} // saveMemGraphLength

- (void)saveMemFreeColor:(NSColor *)color {
	[self saveColorPref:kMemFreeColorPref value:color];
} // saveMemFreeColor

- (void)saveMemUsedColor:(NSColor *)color {
	[self saveColorPref:kMemUsedColorPref value:color];
} // saveMemUsedColor

- (void)saveMemActiveColor:(NSColor *)color {
	[self saveColorPref:kMemActiveColorPref value:color];
} // saveMemActiveColor

- (void)saveMemInactiveColor:(NSColor *)color {
	[self saveColorPref:kMemInactiveColorPref value:color];
} // saveMemInactiveColor

- (void)saveMemWireColor:(NSColor *)color {
	[self saveColorPref:kMemWireColorPref value:color];
} // saveMemWireColor

- (void)saveMemCompressedColor:(NSColor *)color {
	[self saveColorPref:kMemCompressedColorPref value:color];
} // saveMemCompressedColor

- (void)saveMemPageInColor:(NSColor *)color {
	[self saveColorPref:kMemPageInColorPref value:color];
} // saveMemPageinColor

- (void)saveMemPageOutColor:(NSColor *)color {
	[self saveColorPref:kMemPageOutColorPref value:color];
} // saveMemPageoutColor

///////////////////////////////////////////////////////////////
//
//	Net menu prefs
//
///////////////////////////////////////////////////////////////

- (double)netInterval {
	return [self loadDoublePref:kNetIntervalPref
					   lowBound:kNetUpdateIntervalMin
					  highBound:kNetUpdateIntervalMax
				   defaultValue:kNetUpdateIntervalDefault];
} // netInterval

- (int)netDisplayMode {
	return [self loadBitFlagPref:kNetDisplayModePref
					  validFlags:(kNetDisplayThroughput | kNetDisplayGraph | kNetDisplayArrows)
					   zeroValid:NO
					defaultValue:kNetDisplayDefault];
} // netDisplayMode

- (int)netDisplayOrientation {
	return [self loadIntPref:kNetDisplayOrientationPref
					lowBound:kNetDisplayOrientTxRx
				   highBound:kNetDisplayOrientRxTx
				defaultValue:kNetDisplayOrientationDefault];
} // netDisplayOrientation

- (int)netScaleMode {
	return [self loadIntPref:kNetScaleModePref
					lowBound:kNetScaleInterfaceSpeed
				   highBound:kNetScalePeakTraffic
				defaultValue:kNetScaleDefault];
} // netScaleMode

- (int)netScaleCalc {
	return [self loadIntPref:kNetScaleCalcPref
					lowBound:kNetScaleCalcLinear
				   highBound:kNetScaleCalcLog
				defaultValue:kNetScaleCalcDefault];
} // netScaleCalc

- (BOOL)netThroughputLabel {
	return [self loadBoolPref:kNetThroughputLabelPref defaultValue:kNetThroughputLabelDefault];
} // netThroughputLabel

- (BOOL)netThroughput1KBound {
	return [self loadBoolPref:kNetThroughput1KBoundPref defaultValue:kNetThroughput1KBoundDefault];
} // netThroughput1KBound

- (int)netGraphStyle {
	return [self loadIntPref:kNetGraphStylePref
					lowBound:kNetGraphStyleStandard
				   highBound:kNetGraphStyleInverseOpposed
				defaultValue:kNetGraphStyleDefault];
} // netGraphStyle

- (int)netGraphLength {
	return [self loadIntPref:kNetGraphLengthPref
					lowBound:kNetGraphWidthMin
				   highBound:kNetGraphWidthMax
				defaultValue:kNetGraphWidthDefault];
} // netGraphLength

- (NSColor *)netTransmitColor {
	return [self loadColorPref:kNetTransmitColorPref defaultValue:kNetTransmitColorDefault];
} // netTransmitColor

- (NSColor *)netReceiveColor {
	return [self loadColorPref:kNetReceiveColorPref defaultValue:kNetReceiveColorDefault];
} // netReceiveColor

- (NSColor *)netInactiveColor {
	return [self loadColorPref:kNetInactiveColorPref defaultValue:kNetInactiveColorDefault];
} // netInactiveColor

- (NSString *)netPreferInterface {
	return [self loadStringPref:kNetPreferInterfacePref defaultValue:kNetPrimaryInterface];
} // netPreferInterface

- (void)saveNetInterval:(double)interval {
	[self saveDoublePref:kNetIntervalPref value:interval];
} // saveNetInterval

- (void)saveNetDisplayMode:(int)mode {
	[self saveIntPref:kNetDisplayModePref value:mode];
} // saveNetDisplayMode

- (void)saveNetDisplayOrientation:(int)orient {
	[self saveIntPref:kNetDisplayOrientationPref value:orient];
} // saveNetDisplayOrientation

- (void)saveNetScaleMode:(int)mode {
	[self saveIntPref:kNetScaleModePref value:mode];
} // saveNetScaleMode

- (void)saveNetScaleCalc:(int)calc {
	[self saveIntPref:kNetScaleCalcPref value:calc];
} // saveNetScaleCalc

- (void)saveNetThroughputLabel:(BOOL)label {
	[self saveBoolPref:kNetThroughputLabelPref value:label];
} // saveNetThroughputLabel

- (void)saveNetThroughput1KBound:(BOOL)label {
	[self saveBoolPref:kNetThroughput1KBoundPref value:label];
} // saveNetThroughput1KBound

- (void)saveNetGraphStyle:(int)style {
	[self saveIntPref:kNetGraphStylePref value:style];
} // saveNetGraphStyle

- (void)saveNetGraphLength:(int)length {
	[self saveIntPref:kNetGraphLengthPref value:length];
} // saveNetGraphLength

- (void)saveNetTransmitColor:(NSColor *)color {
	[self saveColorPref:kNetTransmitColorPref value:color];
} // saveNetTransmitColor

- (void)saveNetReceiveColor:(NSColor *)color {
	[self saveColorPref:kNetReceiveColorPref value:color];
} // saveNetReceiveColor

- (void)saveNetInactiveColor:(NSColor *)color {
	[self saveColorPref:kNetInactiveColorPref value:color];
} // saveNetInactiveColor

- (void)saveNetPreferInterface:(NSString *)interface {
	[self saveStringPref:kNetPreferInterfacePref value:interface];
} // saveNetPreferInterface

///////////////////////////////////////////////////////////////
//
//	Prefs version migration
//
///////////////////////////////////////////////////////////////

- (void)migratePrefFile {

} // _migratePrefFile

- (void)migratePrefsForward {

} // _migratePrefsForward

///////////////////////////////////////////////////////////////
//
//	Datatype read/write
//
///////////////////////////////////////////////////////////////

- (double)loadDoublePref:(NSString *)prefName lowBound:(double)lowBound highBound:(double)highBound defaultValue:(double)defaultValue {

	double returnVal = defaultValue;
	NSNumber *prefValue = (NSNumber *)CFBridgingRelease(CFPreferencesCopyValue((CFStringRef)prefName,
															 (CFStringRef)kMenuMeterDefaultsDomain,
															 kCFPreferencesCurrentUser, kCFPreferencesAnyHost));
	if (prefValue && [prefValue isKindOfClass:[NSNumber class]]) {
		returnVal = [prefValue doubleValue];
		// Floating point comparison needs some margin of error. Scale up
		// and truncate
		if ((floor(returnVal * 100) < floor(lowBound * 100)) ||
			(ceil(returnVal * 100) > ceil(highBound * 100))) {
			returnVal = defaultValue;
			[self saveDoublePref:prefName value:returnVal];
		}
	} else {
		[self saveDoublePref:prefName value:returnVal];
	}
	return returnVal;

} // _loadDoublePref

- (void)saveDoublePref:(NSString *)prefName value:(double)value {
	CFPreferencesSetValue((CFStringRef)prefName,
						  (__bridge CFPropertyListRef _Nullable)([NSNumber numberWithDouble:value]),
						  (CFStringRef)kMenuMeterDefaultsDomain,
						  kCFPreferencesCurrentUser,
						  kCFPreferencesAnyHost);
} // _saveDoublePref

- (int)loadIntPref:(NSString *)prefName lowBound:(int)lowBound highBound:(int)highBound defaultValue:(int)defaultValue {

	Boolean keyExistsAndHasValidFormat = NO;
	CFIndex returnValue = CFPreferencesGetAppIntegerValue((CFStringRef)prefName,
														  (CFStringRef)kMenuMeterDefaultsDomain,
														  &keyExistsAndHasValidFormat);
	if (!keyExistsAndHasValidFormat) {
		[self saveIntPref:prefName value:defaultValue];
		returnValue = defaultValue;
	}
    if(returnValue > highBound || returnValue < lowBound){
        returnValue = defaultValue;
    }
	return (int) returnValue;

} // _loadIntPref

- (void)saveIntPref:(NSString *)prefname value:(int)value {
	CFPreferencesSetValue((CFStringRef)prefname,
						  (__bridge CFPropertyListRef _Nullable)([NSNumber numberWithInt:value]),
						  (CFStringRef)kMenuMeterDefaultsDomain,
						  kCFPreferencesCurrentUser,
						  kCFPreferencesAnyHost);
} // _saveIntPref

- (int)loadBitFlagPref:(NSString *)prefName validFlags:(int)flags zeroValid:(BOOL)zeroValid defaultValue:(int)defaultValue {

	Boolean keyExistsAndHasValidFormat = NO;
	CFIndex returnValue = CFPreferencesGetAppIntegerValue((CFStringRef)prefName,
														  (CFStringRef)kMenuMeterDefaultsDomain,
														  &keyExistsAndHasValidFormat);
	if (keyExistsAndHasValidFormat) {
		if (((returnValue | flags) != flags) || (zeroValid && !returnValue)) {
			keyExistsAndHasValidFormat = NO;
		}
	}
	
	if (!keyExistsAndHasValidFormat) {
		[self saveIntPref:prefName value:defaultValue];
		returnValue = defaultValue;
	}
	return (int) returnValue;

} // _loadBitFlagPref

- (void)saveBitFlagPref:(NSString *)prefName value:(int)value {
	CFPreferencesSetValue((CFStringRef)prefName,
						  (__bridge CFPropertyListRef _Nullable)([NSNumber numberWithInt:value]),
						  (CFStringRef)kMenuMeterDefaultsDomain,
						  kCFPreferencesCurrentUser,
						  kCFPreferencesAnyHost);
} // _saveBitFlagPref

- (BOOL)loadBoolPref:(NSString *)prefName defaultValue:(BOOL)defaultValue {

	Boolean keyExistsAndHasValidFormat = NO;
	BOOL returnValue = CFPreferencesGetAppBooleanValue((CFStringRef)prefName,
													   (CFStringRef)kMenuMeterDefaultsDomain,
													   &keyExistsAndHasValidFormat);
	if (!keyExistsAndHasValidFormat) {
		[self saveBoolPref:prefName value:defaultValue];
		returnValue = defaultValue;
	}
	return returnValue;

} // _loadBoolPref

- (void)saveBoolPref:(NSString *)prefName value:(BOOL)value {
	CFPreferencesSetValue((CFStringRef)prefName,
						  (__bridge CFPropertyListRef _Nullable)([NSNumber numberWithBool:value]),
						  (CFStringRef)kMenuMeterDefaultsDomain,
						  kCFPreferencesCurrentUser,
						  kCFPreferencesAnyHost);
} // _saveBoolPref

- (NSColor *)loadColorPref:(NSString *)prefName defaultValue:(NSColor *)defaultValue {

	NSColor *returnValue = nil;
	CFDataRef archivedData = CFPreferencesCopyValue((CFStringRef)prefName,
													(CFStringRef)kMenuMeterDefaultsDomain,
													kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	if (archivedData && (CFGetTypeID(archivedData) == CFDataGetTypeID())) {
		returnValue = [NSUnarchiver unarchiveObjectWithData:(__bridge NSData *)archivedData];
	}

    if (!returnValue) {
		[self saveColorPref:prefName value:defaultValue];
		returnValue = defaultValue;
	}

    if (archivedData) {
        CFRelease(archivedData);
    }

    return returnValue;
} // _loadColorPref

- (void)saveColorPref:(NSString *)prefName value:(NSColor *)value {
	if (value) {
		CFPreferencesSetValue((CFStringRef)prefName,
							  (__bridge CFPropertyListRef _Nullable)([NSArchiver archivedDataWithRootObject:value]),
							  (CFStringRef)kMenuMeterDefaultsDomain,
							  kCFPreferencesCurrentUser,
							  kCFPreferencesAnyHost);
	}
} // _saveColorPref

- (NSString *)loadStringPref:(NSString *)prefName defaultValue:(NSString *)defaultValue {

	NSString *returnValue = NULL;
	CFStringRef prefValue = CFPreferencesCopyValue((CFStringRef)prefName,
												   (CFStringRef)kMenuMeterDefaultsDomain,
												   kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    if (prefValue) {
        if (CFGetTypeID(prefValue) == CFStringGetTypeID()) {
            returnValue = (NSString *)CFBridgingRelease(prefValue);
        } else {
            CFBridgingRelease(prefValue);
        }
    }

    if (returnValue == NULL) {
        returnValue = defaultValue;
        [self saveStringPref:prefName value:returnValue];
    }

    return returnValue;

} // _loadStringPref

- (void)saveStringPref:(NSString *)prefName value:(NSString *)value {
	CFPreferencesSetValue((CFStringRef)prefName,
						  (CFStringRef)value,
						  (CFStringRef)kMenuMeterDefaultsDomain,
						  kCFPreferencesCurrentUser,
						  kCFPreferencesAnyHost);
} // _saveStringPref

@end
