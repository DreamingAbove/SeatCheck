# SeatCheck iOS App - Complete Documentation

## 📱 Overview

SeatCheck is an iOS app designed to help users avoid leaving personal belongings behind in rideshares and other temporary spaces. The app uses smart detection, customizable checklists, and timely notifications to ensure users remember to check their surroundings before leaving.

## 🎯 Key Features

### Core Functionality
- **1-tap session start** with preset options (Ride, Café, Classroom, Flight, Custom)
- **Smart end prompts** using location, motion, and Bluetooth detection
- **Customizable checklists** for common items (phone, wallet, keys, etc.)
- **Live Activities** showing session progress on Lock Screen and Dynamic Island
- **Camera scan** for visual seat sweeping
- **Session history** with streaks and statistics

### Smart Detection
- **Location-based**: Geofencing to detect when leaving a location
- **Motion-based**: Activity recognition to detect movement patterns
- **Bluetooth-based**: Device disconnection detection (AirPods, car Bluetooth, etc.)
- **Timer-based**: Automatic session expiration

### Notifications
- **Session expired notifications** with quick actions
- **Smart detection alerts** for potential exits
- **Streak achievement notifications** for motivation
- **Snooze reminders** for delayed checks

## 🏗️ Architecture

### Core Components

#### Data Models (`Item.swift`)
- **Session**: Main session entity with timer, checklist, and status
- **ChecklistItem**: Individual items to check during sessions
- **Settings**: App preferences and default checklist items
- **Enums**: SessionPreset, EndSignal for type safety

#### Managers
- **TimerManager**: Handles session countdown and background execution
- **LiveActivityManager**: Manages Live Activities for session progress
- **NotificationManager**: Handles all notification types and actions
- **SensorManager**: Manages location and motion detection
- **BluetoothManager**: Handles Bluetooth device monitoring
- **ErrorHandler**: Comprehensive error handling and logging

#### Views
- **ContentView**: Main dashboard with quick start and session history
- **SessionDetailView**: Detailed session view with timer and checklist
- **CameraScanView**: Camera interface for visual seat scanning
- **ChecklistSettingsView**: Customizable checklist management
- **SessionHistoryView**: Session statistics and streak tracking
- **NotificationSettingsView**: Notification preferences

### Design System (`AppTheme.swift`)
- **Colors**: Consistent color palette with semantic meanings
- **Typography**: Standardized font sizes and weights
- **Spacing**: Consistent spacing system
- **Shadows**: Elevation and depth system
- **Animations**: Smooth, consistent animations
- **Button Styles**: Reusable button components

## 🚀 Setup Instructions

### Prerequisites
- Xcode 15.0+
- iOS 17.0+
- Swift 5.9+
- Apple Developer Account (for device testing)

### Installation
1. Clone the repository
2. Open `SeatCheck.xcodeproj` in Xcode
3. Select your development team
4. Build and run on device or simulator

### Required Permissions

#### Info.plist Entries
Add these entries to your project's `Info.plist`:

```xml
<!-- Location Permissions -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>SeatCheck uses location to detect when you're leaving a location and remind you to check your belongings.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>SeatCheck uses location in the background to detect when you're leaving a location and remind you to check your belongings.</string>

<!-- Motion Permissions -->
<key>NSMotionUsageDescription</key>
<string>SeatCheck uses motion detection to understand your activity and provide better reminders.</string>

<!-- Camera Permissions -->
<key>NSCameraUsageDescription</key>
<string>SeatCheck needs camera access to help you scan your seat area for forgotten items.</string>

<!-- Bluetooth Permissions -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>SeatCheck uses Bluetooth to detect when your connected devices disconnect, helping to remind you to check your belongings when you leave.</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>SeatCheck monitors Bluetooth device connections to help detect when you're leaving a location.</string>
```

#### Background Modes
Enable these background modes in your Xcode project:
- Location updates
- Background processing
- Background app refresh

## 📋 Usage Guide

### Starting a Session
1. **Quick Start**: Tap "Quick Start Ride" for a 30-minute ride session
2. **Custom Session**: Tap "Custom Session" to choose preset and duration
3. **Session begins**: Live Activity appears on Lock Screen
4. **Smart monitoring**: Location, motion, and Bluetooth monitoring starts

### During a Session
- **Timer display**: See remaining time in app and Live Activity
- **Checklist management**: Mark items as collected
- **Pause/Resume**: Control session timing
- **Manual end**: End session early if needed

### Session End
- **Automatic detection**: Smart detection triggers session end
- **Notification**: High-priority notification with quick actions
- **Quick actions**: Mark all collected, snooze, or scan seat
- **Camera scan**: Visual seat checking with camera

### Customization
- **Checklist settings**: Add/remove default items
- **Notification preferences**: Customize notification types
- **Session history**: View statistics and streaks

## 🔧 Technical Details

### SwiftData Integration
- **Model Container**: Configured in `SeatCheckApp.swift`
- **Schema**: Session, ChecklistItem, Settings models
- **Persistence**: Automatic data persistence and migration

### Live Activities
- **ActivityKit**: Modern API usage with content states
- **Widget Extension**: Separate target for Live Activity UI
- **Background Updates**: Timer-based updates during sessions

### Background Processing
- **Background Tasks**: UIBackgroundTaskIdentifier for timer continuation
- **Location Services**: Background location updates with geofencing
- **Motion Detection**: CMMotionActivityManager for activity recognition

### Notification System
- **Categories**: Multiple notification categories with custom actions
- **Rich Content**: Emoji-rich titles and descriptive messages
- **Action Handling**: Comprehensive action handling with app integration

### Error Handling
- **Error Types**: Specific error types for different scenarios
- **User Feedback**: Clear error messages with recovery suggestions
- **Logging**: Comprehensive logging with OSLog integration

## 🐛 Troubleshooting

### Common Issues

#### Permissions Not Working
- **Check Info.plist**: Ensure all required permission entries are present
- **Settings**: Verify permissions are granted in iOS Settings
- **Simulator**: Some features require physical device testing

#### Live Activities Not Showing
- **ActivityKit**: Requires iOS 16.1+ and physical device
- **Background Modes**: Ensure background processing is enabled
- **App State**: Live Activities may not show in simulator

#### Bluetooth Detection Issues
- **Device Support**: Bluetooth detection requires physical device
- **Permissions**: Ensure Bluetooth permissions are granted
- **Device Connection**: Devices must be connected before session starts

#### Timer Issues
- **Background Execution**: Check background modes configuration
- **App Lifecycle**: Timer may pause when app is backgrounded
- **Device Restrictions**: Some devices may limit background execution

### Debugging
- **Console Logs**: Check Xcode console for detailed logs
- **Error Handler**: App includes comprehensive error handling
- **Log Categories**: Different log categories for different components

## 📊 Performance Considerations

### Battery Optimization
- **Location Services**: Efficient geofencing with appropriate radius
- **Motion Detection**: Activity-based monitoring to reduce battery usage
- **Background Tasks**: Limited background execution time
- **Timer Efficiency**: 1-second timer updates with background task management

### Memory Management
- **SwiftData**: Automatic memory management for data models
- **Manager Singletons**: Efficient singleton pattern for managers
- **View Lifecycle**: Proper cleanup in view lifecycle methods

### Network Usage
- **Local Storage**: All data stored locally with SwiftData
- **No Network Calls**: App functions entirely offline
- **Future Expansion**: Architecture supports future cloud integration

## 🔮 Future Enhancements

### Planned Features
- **Vision Framework**: AI-powered item detection in camera scans
- **Cloud Sync**: iCloud integration for data synchronization
- **Widgets**: Home Screen widgets for quick session start
- **Siri Integration**: Voice commands for session control
- **Apple Watch**: Companion app for quick interactions

### Technical Improvements
- **Performance**: Further battery and memory optimization
- **Accessibility**: Enhanced accessibility features
- **Localization**: Multi-language support
- **Analytics**: Privacy-focused usage analytics

## 📝 Development Notes

### Code Organization
- **MVVM Pattern**: Model-View-ViewModel architecture
- **Manager Pattern**: Singleton managers for system services
- **Protocol-Oriented**: Swift protocol usage for flexibility
- **Error Handling**: Comprehensive error handling throughout

### Testing Strategy
- **Unit Tests**: Core logic and manager testing
- **Integration Tests**: End-to-end session flow testing
- **UI Tests**: User interface interaction testing
- **Device Testing**: Physical device testing for all features

### Deployment
- **App Store**: Ready for App Store submission
- **TestFlight**: Beta testing configuration
- **Code Signing**: Proper code signing and provisioning
- **App Review**: Guidelines compliance and review preparation

## 📞 Support

### Documentation
- **Code Comments**: Comprehensive inline documentation
- **README**: Project overview and setup instructions
- **API Documentation**: Detailed API documentation
- **User Guide**: End-user documentation

### Contact
- **Issues**: GitHub issues for bug reports
- **Feature Requests**: GitHub discussions for feature ideas
- **Contributions**: Pull requests welcome for improvements

---

**SeatCheck** - Never leave your belongings behind! 📱✨
