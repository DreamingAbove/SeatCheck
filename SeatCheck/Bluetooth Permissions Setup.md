# Bluetooth Permissions Setup for SeatCheck

## Overview
The SeatCheck app includes Bluetooth monitoring to detect when connected devices (like AirPods, car Bluetooth, etc.) disconnect, which can serve as an end signal for sessions. This feature requires Bluetooth permissions to function properly.

## Required Info.plist Entries

Add the following entries to your Xcode project's `Info.plist` file:

### Bluetooth Usage Description
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>SeatCheck uses Bluetooth to detect when your connected devices (like AirPods or car Bluetooth) disconnect, helping to remind you to check your belongings when you leave.</string>
```

### Bluetooth Peripheral Usage Description
```xml
<key>NSBluetoothPeripheralUsageDescription</key>
<string>SeatCheck monitors Bluetooth device connections to help detect when you're leaving a location.</string>
```

## How to Add These Entries

1. Open your Xcode project
2. Select your project in the navigator
3. Select your target
4. Go to the "Info" tab
5. Add the keys and values above to the "Custom iOS Target Properties" section

## Bluetooth Features

The Bluetooth monitoring feature includes:
- **Device connection tracking** for connected Bluetooth devices
- **Disconnection detection** with 10-second grace period
- **Automatic session ending** when devices don't reconnect
- **Visual status indicators** showing connection state
- **Permission handling** with user-friendly prompts

## How It Works

1. **Session Start**: When a session begins, Bluetooth monitoring starts
2. **Device Tracking**: The app tracks all connected Bluetooth devices
3. **Disconnection Detection**: When a device disconnects, a 10-second timer starts
4. **Grace Period**: User has 10 seconds to reconnect the device
5. **Session End**: If device doesn't reconnect, session ends with Bluetooth end signal

## Integration Points

The Bluetooth monitoring is integrated with:
1. **TimerManager**: Starts/stops monitoring with sessions
2. **SessionDetailView**: Shows Bluetooth status and connected devices
3. **EndSignal System**: Uses `.bluetooth` end signal type
4. **Notification System**: Can trigger notifications on disconnection

## Privacy Considerations

- **No data collection**: Device names are only used locally
- **No tracking**: Only monitors connection state, not device data
- **User control**: Can be disabled in settings
- **Transparent**: Clear permission descriptions explain usage

## Troubleshooting

### Common Issues:
1. **Bluetooth not working**: Check device Bluetooth is enabled
2. **Permission denied**: User must grant Bluetooth permissions
3. **No devices detected**: Ensure devices are connected before starting session
4. **False disconnections**: 10-second grace period prevents accidental triggers

### Testing:
- Connect AirPods or other Bluetooth device
- Start a session
- Disconnect the device
- Wait 10 seconds for session to end
- Reconnect within 10 seconds to cancel session end
