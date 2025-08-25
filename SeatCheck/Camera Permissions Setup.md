# Camera Permissions Setup for SeatCheck

## Overview
The SeatCheck app includes a camera scan feature that allows users to visually sweep their seat area to check for forgotten items. This feature requires camera permissions to function properly.

## Required Info.plist Entries

Add the following entries to your Xcode project's `Info.plist` file:

### Camera Usage Description
```xml
<key>NSCameraUsageDescription</key>
<string>SeatCheck needs camera access to help you scan your seat area for forgotten items. This allows you to visually check your surroundings before leaving.</string>
```

### Photo Library Usage Description (Optional - for future gallery integration)
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>SeatCheck can access your photo library to save scanned images for reference.</string>
```

## How to Add These Entries

1. Open your Xcode project
2. Select your project in the navigator
3. Select your target
4. Go to the "Info" tab
5. Add the keys and values above to the "Custom iOS Target Properties" section

## Camera Features

The camera scan feature includes:
- **Real-time camera preview** for visual seat sweeping
- **Flash control** for low-light conditions
- **Camera switching** between front and back cameras
- **Photo capture** for reference
- **Permission handling** with user-friendly alerts

## Integration Points

The camera scan is accessible from:
1. **Main dashboard** - "Scan Seat" button
2. **Notification actions** - "Scan Seat" action in session expired notifications
3. **Session detail view** - Future integration for session-specific scans

## Future Enhancements

- **Vision framework integration** for automatic item detection
- **Photo library integration** for saving and reviewing scans
- **AR overlay** for highlighting potential items
- **Machine learning** for personalized item recognition
