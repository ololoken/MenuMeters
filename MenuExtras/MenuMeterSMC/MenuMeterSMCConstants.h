//
//  MenuMeterSMCConstants.h
//  MenuMeters
//
//  Created by Roman Turchin on 5/17/19.
//

#ifndef MenuMeterSMCConstants_h
#define MenuMeterSMCConstants_h

enum {
    kSMCDisplayBig = 0,
    kSMCDisplaySmall
};

// Orange
#define kSMCTemperatureCPUColorDefault         [NSColor colorWithDeviceRed:1.0f green:0.647f blue:0.0f alpha:1.0f]
#define kSMCTemperatureGPUColorDefault         [NSColor colorWithDeviceRed:1.0f green:0.647f blue:0.0f alpha:1.0f]

#define kSMCPowerCPUColorDefault               [NSColor colorWithDeviceRed:1.0f green:0.647f blue:0.0f alpha:1.0f]
#define kSMCPowerAllColorDefault               [NSColor colorWithDeviceRed:1.0f green:0.647f blue:0.0f alpha:1.0f]

#define SMC_CPU_TEMP                           "TC0P"
#define SMC_GPU_TEMP                           "TG0D"

#define SMC_CPU_POWER                          "PC0C"
#define SMC_ALL_POWER                          "PSTR"

#endif /* MenuMeterSMCConstants_h */
