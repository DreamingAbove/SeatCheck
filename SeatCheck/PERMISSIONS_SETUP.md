# SeatCheck Permissions Setup

## Required Info.plist Entries

To enable location and motion sensors, you need to add the following entries to your Info.plist file in the Xcode project:

### Location Permissions
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>SeatCheck uses your location to create geofences and detect when you leave your seat area to remind you to check your belongings.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>SeatCheck uses your location to create geofences and detect when you leave your seat area to remind you to check your belongings.</string>
```

### Motion Permissions
```xml
<key>NSMotionUsageDescription</key>
<string>SeatCheck uses motion data to detect when you exit vehicles or become stationary to remind you to check your belongings.</string>
```

### Background Modes
```xml
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>background-processing</string>
</array>
```

## How to Add in Xcode

1. Open your Xcode project
2. Select your target
3. Go to the "Info" tab
4. Add the above keys and values to the Info.plist

## Alternative: Add Programmatically

If you prefer to add these programmatically, you can add them to your project's build settings or create a custom Info.plist file.

## Current Status

The app will work without these permissions, but location and motion features will be disabled. Users will see "Location Disabled" and "Motion Disabled" in the sensor status section.
