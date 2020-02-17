import Foundation
import bgxpress
import CoreBluetooth

@available(iOS 10, macOS 10.13, *)
public class pillowcase: NSObject {
    
    public static let shared = pillowcase()
    
    public weak var delegate: pillowcaseDelegate?
    var bgxScanner: BGXpressScanner = BGXpressScanner()
    var selectedDevice: BGXDevice? = nil
    var savedDeviceUUID: String?
    var bluetoothReady: Bool = false
    var isScanning: Bool = false
    var foundDevices: [BGXDevice] = []
    var connectToAnyDevice: Bool = false
    var requiredBoardVersion = "1.0.0"
    var scanIndefinitely: Bool = true
    var isUpdating: Bool = false
    var updateStepIndex = 0
    let updateSteps = [
        "gfu 1 ufu_level",
        "gfu 2 ufu_level",
        "gfu 3 ufu_level",
        "gfu 4 ufu_level",
        "gfu 5 ufu_level",
        "gfu 6 ufu_level",
        "gfu 7 ufu_level",
        "gdi 1 ipuw db0",
        "gdi 2 ipuw db0",
        "gdi 3 ipuw db0",
        "gdi 4 ipuw db0",
        "gdi 5 ipuw db0",
        "gdi 6 ipuw db0",
        "gdi 7 ipuw db0",
        "uevt 0 con",
        "uevt 1 hi 1",
        "uevt 2 hi 2",
        "uevt 3 hi 3",
        "uevt 4 hi 4",
        "uevt 5 hi 5",
        "uevt 6 hi 6",
        "uevt 7 hi 7",
        "ufu 0 send \"pcv-1.0.1\"",
        "ufu 1 send \"in_1\"",
        "ufu 2 send \"in_2\"",
        "ufu 3 send \"in_3\"",
        "ufu 4 send \"in_4\"",
        "ufu 5 send \"in_5\"",
        "ufu 6 send \"in_6\"",
        "ufu 7 send \"in_7\"",
        "set sy d n \"PillCase-#####\"",
        "set sy i m \"Hatchmed\"",
        "set sy i p \"Pillow Case\"",
        "save",
    ]
    
    private override init() {
        super.init()
        bgxScanner.delegate = self
    }

    /**
     (REQUIRED) Starts pillowcase with config options and begins scanning for compatible boards
     
     - parameters:
        - forceReset: resets device memory from previous sessions such as pillowcase UUID and previously discovered devices
        - connectToFirstAvailableDevice: allow device to connect to any available pillowcase. Primarily used for development and testing
     */
    public func configure(forceReset: Bool = false, connectToFirstAvailableDevice: Bool = false) {
        if (forceReset) {
            self.reset()
        }
        self.connectToAnyDevice = connectToFirstAvailableDevice
        savedDeviceUUID = UserDefaults.standard.string(forKey: "SavedPillowcaseUUID") ?? nil
        self.scanIndefinitely = (savedDeviceUUID != nil || connectToFirstAvailableDevice)
        self.getDevices()
    }

    /**
      Connects to pillowcase board with provided UUID.
     
     - parameters:
        - uuid: UUID of pillowcase board
     - throws: `PillowcaseError.deviceNotFound` error if a device with provided uuid is not found
     */
    public func connect(uuid: String) throws {
        self.disconnect()
        var deviceFound = false
        if (!foundDevices.isEmpty) {
            for device in foundDevices {
                if (device.identifier.uuidString == uuid) {
                    deviceFound = true
                    UserDefaults.standard.set(device.identifier.uuidString, forKey: "SavedPillowcaseUUID")
                    self.selectedDevice = device
                    self.selectedDevice!.deviceDelegate = self
                    self.selectedDevice!.serialDelegate = self
                    self.selectedDevice!.connect()
                }
            }
        }
        if (!deviceFound) {
            throw PillowcaseError.deviceNotFound
        }
    }
    
    /**
     Connects to pillowcase device
     
     - parameters:
        - device: BGXDevice provided from BGXpressScanner
     */
    public func connect(device: BGXDevice) {
        UserDefaults.standard.set(device.identifier.uuidString, forKey: "SavedPillowcaseUUID")
        self.savedDeviceUUID = device.identifier.uuidString
        self.selectedDevice = device
        self.selectedDevice!.deviceDelegate = self
        self.selectedDevice!.serialDelegate = self
        self.scanIndefinitely = true
        self.selectedDevice!.connect()
        self.bgxScanner.stopScan()
        self.isScanning = false
    }
    
    /**
     Disconnects from pillowcase device
     
     - parameters:
        - reset: Removes device uuid from memory to prevent automatically reconnecting
     */
    public func disconnect(_ reset: Bool = false) {
        if (self.selectedDevice != nil) {
            self.scanIndefinitely = false
            self.selectedDevice!.disconnect()
            self.selectedDevice = nil
            if (reset) {
                self.reset()
            }
        }
    }
    
    /**
     Scans for pillowcase devices
     
     - parameters:
        - indefinite: will scan for devices until any pillowcase is found (connectToFirstAvailableDevice = true) or the saved pillowcase is found
     */
    public func getDevices(_ indefinite: Bool = false) {
        if (bluetoothReady) {
            if (!isScanning) {
                isScanning = true
                bgxScanner.startScan()
                if (!self.scanIndefinitely) {
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(10)) {
                        self.bgxScanner.stopScan()
                        self.isScanning = false
                    }
                }
            }
        }
    }
    
    func reset() {
        UserDefaults.standard.set(nil, forKey: "SavedPillowcaseUUID")
        selectedDevice = nil
        savedDeviceUUID = nil
        self.bgxScanner.devicesDiscovered = []
        self.bgxScanner.stopScan()
        self.foundDevices = []
    }
    
    func checkForUpdates(_ version: String? = nil) {
        self.updateStepIndex = 0
        if (version == nil || version! < self.requiredBoardVersion) {
            self.selectedDevice?.writeBusMode(REMOTE_COMMAND_MODE, password: nil, completionHandler: { (device, error) in
                self.isUpdating = true
                self.delegate?.boardUpdateStateChange(true)
                self.updateBoard()
            })
        }
    }
    
    func updateBoard() {
        self.selectedDevice?.sendCommand(updateSteps[updateStepIndex], args: "")
        self.updateStepIndex += 1
    }
}

@available(iOS 10, macOS 10.13, *)
extension pillowcase: BGXpressScanDelegate, BGXDeviceDelegate, BGXSerialDelegate {

    public func deviceDiscovered(_ device: BGXDevice) {
        self.foundDevices = (self.bgxScanner.devicesDiscovered as? [BGXDevice] ?? [])
        if !self.foundDevices.isEmpty {
            if self.connectToAnyDevice {
                self.connect(device: self.foundDevices[0])
            } else if (self.savedDeviceUUID == nil) {
                self.delegate?.foundDevices(self.foundDevices)
            } else {
                for device in self.foundDevices {
                    if (device.identifier.uuidString == self.savedDeviceUUID) {
                        self.connect(device: device)
                    }
                }
            }
        }
    }

    public func bluetoothStateChanged(_ state: CBManagerState) {
        self.delegate?.bluetoothStateUpdate(state)
        switch state {
        case .poweredOn:
            bluetoothReady = true
            self.selectedDevice = nil
            self.bgxScanner.devicesDiscovered = []
            self.foundDevices = []
            self.getDevices()
        case .unknown, .resetting, .unsupported, .unauthorized, .poweredOff:
            fallthrough
        default:
            bluetoothReady = false
            self.isScanning = false
        }
    }

    public func stateChanged(for device: BGXDevice) {
        self.delegate?.deviceStateChange(device.deviceState)
        switch (device.deviceState) {
        case .Connected:
            UserDefaults.standard.set(device.identifier.uuidString, forKey: "SavedPillowcaseUUID")
            selectedDevice = device
            self.checkForUpdates()
        case .Disconnected:
            device.deviceDelegate = nil
            device.serialDelegate = nil
            self.selectedDevice = nil
            self.isScanning = false
            self.getDevices()
        case .Connecting:
            break
        case .Interrogating:
            break
        case .Disconnecting:
            break
        default:
            break
        }
    }

    public func dataRead(_ newData: Data, for device: BGXDevice) {
        let data = String(data: newData, encoding: .utf8)
        if (data == nil) {
            return
        }
        if (data!.starts(with: "in_")) {
            let buttonNum = Int(data!.replacingOccurrences(of: "in_", with: ""))
            if (buttonNum != nil) {
                self.delegate?.buttonPressed(buttonNum!)
            }
        }
    }

    public func busModeChanged(_ newBusMode: BusMode, for device: BGXDevice) {
        var currentBusMode = "UNKNOWN_MODE"
        switch (newBusMode) {
        case STREAM_MODE:
          currentBusMode = "STREAM_MODE"
        case LOCAL_COMMAND_MODE:
          currentBusMode = "LOCAL_COMMAND_MODE"
        case REMOTE_COMMAND_MODE:
          currentBusMode = "REMOTE_COMMAND_MODE"
        case UNSUPPORTED_MODE:
          currentBusMode = "UNSUPPORTED_MODE"
        default:
            currentBusMode = "UNKNOWN_MODE"
        }
    }

    public func dataWritten(for device: BGXDevice) {
        if (updateStepIndex < updateSteps.count) {
            self.updateBoard()
        } else {
            self.selectedDevice?.writeBusMode(STREAM_MODE, password: nil, completionHandler: { (device, err) in
                self.isUpdating = false
                self.delegate?.boardUpdateStateChange(false)
            })
        }
    }
}

public protocol pillowcaseDelegate: AnyObject {
    /**
     Notification that a button on the pillowccase was pressed
     
     - parameters:
       - buttonNumber: button on the pillowcase board that was pressed
     */
    func buttonPressed(_ buttonNumber: Int)
    
    /**
     Returns a list of found pillowcase devices
     
     - parameters:
        - devices: Compatible Pillowcase devices of type BGXDevice
     */
    func foundDevices(_ devices: [BGXDevice])
    
    /**
     Notification of a device state change.
     ```
        enum deviceState {
            case Interrogating
            case Disconnected
            case Connecting
            case Connected
            case Disconnecting
        }
     ```
     
     - parameters:
        - state: current pillowcase device state from the DeviceState enum.
     */
    func deviceStateChange(_ state: DeviceState?)
    
    /**
     Notification that the current Bluetooth state of the iOS device has changed
     
     ```
     enum CBManagerState : Int {
         case unknown
         case resetting
         case unsupported
         case unauthorized
         case poweredOff
         case poweredOn
     }
     ```
     
     - parameters:
        - state: current Bluetooth state of the iOS device
     */
    func bluetoothStateUpdate(_ state: CBManagerState)
    
    /**
     Current update status of the pillowcase device.
     
     When first connected, the pillowcase device will be updated to match the required configuration necessary to work properly with the iOS device
     
     - parameters:
        - state: boolean value indicating whether the device is currently updating
     */
    func boardUpdateStateChange(_ state: Bool)
}

public enum PillowcaseError: Error {
    case deviceNotFound
}
