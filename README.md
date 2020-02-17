# pillowcase
Pillowcase is a package created by Hatchmed to provide an easy to implement solution with Pillowcase branded devices.

## Features
- [x] Scan for pillowcase devices
- [x] Automate device updates
- [x] Easy to configure button mapping

## Requirements
- iOS 10.0+ / macOS 10.12+
- Xcode 10.2+

## Installing
### Swift Package Manager
```swift
dependencies: [
    .package(url: "https://github.com/mattpow/pillowcas.git", from: "1.0")
]
```

## Usage
### Initialization
```swift
import pillowcase
import bgxpress

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
  pillowcase.shared.configure()
  pillowcase.shared.delegate = self 
}
```

### Delegate
```swift
extension AppDelegate: pillowcaseDelegate {
  func boardUpdateStateChange(_ state: Bool) {
    // Pillowcase device's update status
  }
  
  func bluetoothStateUpdate(_ state: CBManagerState) {
    // iOS device's bluetooth state
  }
  
  func buttonPressed(_ buttonNumber: Int) {
    // Notification of a button press on the pillowcase
  }
  
  func deviceStateChange(_ state: DeviceState?) {
    // status of a pillowcase device (i.e. Connecting -> Connected)
  }
  
  func foundDevices(_ devices: [BGXDevice]) {
    // Array of found pillowcase devices. 
    // Show a list of devices to choose from
    // and connect to one using pillowcase.connect(device: BGXDevice)
  }
}
```