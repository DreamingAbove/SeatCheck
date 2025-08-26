# Info.plist Setup Guide for SeatCheck

## 🚨 Critical Issues to Fix

The app is crashing due to missing Info.plist configurations. Follow these steps to fix the issues:

## 1. Core Data Directory Issue

The app can't create the Application Support directory. This is a common issue in iOS apps.

### Solution:
Add this to your Info.plist:

```xml
<key>NSApplicationSupportDirectoryUsageDescription</key>
<string>SeatCheck needs to create a directory to store your session data and settings.</string>
```

## 2. Location Services Configuration

The app is trying to use background location without proper configuration.

### Required Info.plist Entries:

```xml
<!-- Location Usage Descriptions -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>SeatCheck uses your location to detect when you leave a location and remind you to check your belongings.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>SeatCheck uses your location in the background to detect when you leave a location and remind you to check your belongings.</string>

<!-- Background Modes (if you want background location) -->
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>background-processing</string>
</array>
```

## 3. Motion & Fitness

```xml
<key>NSMotionUsageDescription</key>
<string>SeatCheck uses motion data to detect when you're moving and help determine if you've left your seat.</string>
```

## 4. Camera Access

```xml
<key>NSCameraUsageDescription</key>
<string>SeatCheck needs camera access to help you scan your seat area for forgotten items.</string>
```

## 5. Bluetooth Access

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>SeatCheck uses Bluetooth to detect when your connected devices disconnect, helping to remind you to check your belongings.</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>SeatCheck monitors Bluetooth device connections to help detect when you're leaving a location.</string>
```

## 6. Notifications

```xml
<key>NSUserNotificationUsageDescription</key>
<string>SeatCheck sends notifications to remind you to check your belongings when you leave a location.</string>
```

## Complete Info.plist Example

Here's a complete Info.plist structure:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- App Information -->
    <key>CFBundleDisplayName</key>
    <string>SeatCheck</string>
    
    <key>CFBundleIdentifier</key>
    <string>com.yourcompany.SeatCheck</string>
    
    <key>CFBundleVersion</key>
    <string>1.0</string>
    
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    
    <!-- Required Device Capabilities -->
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>armv7</string>
        <string>location-services</string>
    </array>
    
    <!-- Supported Interface Orientations -->
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    
    <!-- Background Modes -->
    <key>UIBackgroundModes</key>
    <array>
        <string>location</string>
        <string>background-processing</string>
    </array>
    
    <!-- Permission Descriptions -->
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>SeatCheck uses your location to detect when you leave a location and remind you to check your belongings.</string>
    
    <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
    <string>SeatCheck uses your location in the background to detect when you leave a location and remind you to check your belongings.</string>
    
    <key>NSMotionUsageDescription</key>
    <string>SeatCheck uses motion data to detect when you're moving and help determine if you've left your seat.</string>
    
    <key>NSCameraUsageDescription</key>
    <string>SeatCheck needs camera access to help you scan your seat area for forgotten items.</string>
    
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>SeatCheck uses Bluetooth to detect when your connected devices disconnect, helping to remind you to check your belongings.</string>
    
    <key>NSBluetoothPeripheralUsageDescription</key>
    <string>SeatCheck monitors Bluetooth device connections to help detect when you're leaving a location.</string>
    
    <!-- Application Support Directory -->
    <key>NSApplicationSupportDirectoryUsageDescription</key>
    <string>SeatCheck needs to create a directory to store your session data and settings.</string>
    
    <!-- Privacy Settings -->
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

## How to Add These to Your Xcode Project

1. **Open your Xcode project**
2. **Select your project in the navigator**
3. **Select your target**
4. **Go to the "Info" tab**
5. **Add the keys and values above**

## Alternative: Add Programmatically

If you prefer to add these programmatically, you can add them to your project's build settings or create a custom Info.plist file.

## Testing After Changes

After adding these entries:

1. **Clean your project** (Product → Clean Build Folder)
2. **Delete the app from simulator/device**
3. **Build and run again**

The Core Data and location issues should be resolved!

## Troubleshooting

If you still see issues:

1. **Check that all keys are properly formatted**
2. **Ensure no typos in the key names**
3. **Verify the app has proper entitlements**
4. **Check that background modes are enabled in capabilities**

## Next Steps

After fixing the Info.plist:

1. ✅ **Core Data will work properly**
2. ✅ **Location services will function correctly**
3. ✅ **Background processing will be available**
4. ✅ **All permissions will be properly requested**

The app should now run without crashes! 🎉
