import Foundation
import IOKit.hid

public struct F75HIDDevice: Identifiable, Hashable, Sendable {
    public let registryID: UInt64
    public var id: UInt64 { registryID }
    public let vendorID: Int
    public let productID: Int
    public let manufacturer: String
    public let product: String
    public let serialNumber: String
    public let transport: String
    public let locationID: Int
    public let usagePage: Int
    public let usage: Int
    public let maxFeatureReportSize: Int

    fileprivate init(_ device: IOHIDDevice) throws {
        var entryID: UInt64 = 0
        let status = IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(device), &entryID)
        guard status == kIOReturnSuccess else { throw F75HIDError.io("Read device identity", status) }
        func number(_ key: String) -> Int {
            (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue ?? 0
        }
        func string(_ key: String) -> String {
            IOHIDDeviceGetProperty(device, key as CFString) as? String ?? ""
        }
        registryID = entryID
        vendorID = number(kIOHIDVendorIDKey)
        productID = number(kIOHIDProductIDKey)
        manufacturer = string(kIOHIDManufacturerKey)
        product = string(kIOHIDProductKey)
        serialNumber = string(kIOHIDSerialNumberKey)
        transport = string(kIOHIDTransportKey)
        locationID = number(kIOHIDLocationIDKey)
        usagePage = number(kIOHIDPrimaryUsagePageKey)
        usage = number(kIOHIDPrimaryUsageKey)
        maxFeatureReportSize = number(kIOHIDMaxFeatureReportSizeKey)
    }
}

public enum F75HIDError: Error, LocalizedError {
    case deviceUnavailable
    case closed
    case invalidReport(String)
    case io(String, IOReturn)

    public var errorDescription: String? {
        switch self {
        case .deviceUnavailable: "The selected HID interface is no longer connected. Refresh devices and select it again."
        case .closed: "The HID connection is closed."
        case .invalidReport(let reason): "Invalid HID feature report: \(reason)"
        case .io(let operation, let status):
            "\(operation) failed (IOKit \(String(format: "0x%08X", UInt32(bitPattern: status))))."
        }
    }
}

/// Does not register keyboard callbacks, seize devices, or send reports during discovery.
public final class F75HIDTransport {
    public let device: F75HIDDevice
    private let lock = NSLock()
    private var handle: IOHIDDevice?

    public static func enumerateDevices(
        vendorID: Int? = nil, productID: Int? = nil,
        usagePage: Int? = nil, usage: Int? = nil
    ) throws -> [F75HIDDevice] {
        let handles = matchingDevices(vendorID: vendorID, productID: productID,
                                      usagePage: usagePage, usage: usage)
        return try handles.map { try F75HIDDevice($0) }.sorted { $0.registryID < $1.registryID }
    }

    public init(device: F75HIDDevice) throws {
        self.device = device
        let handles = Self.matchingDevices(vendorID: device.vendorID, productID: device.productID,
                                          usagePage: device.usagePage, usage: device.usage)
        guard let selected = try handles.first(where: { try F75HIDDevice($0).registryID == device.registryID }) else {
            throw F75HIDError.deviceUnavailable
        }
        let status = IOHIDDeviceOpen(selected, IOOptionBits(kIOHIDOptionsTypeNone))
        guard status == kIOReturnSuccess else { throw F75HIDError.io("Open HID interface", status) }
        handle = selected
    }

    deinit { close() }

    public func close() {
        lock.lock()
        defer { lock.unlock() }
        if let handle {
            IOHIDDeviceClose(handle, IOOptionBits(kIOHIDOptionsTypeNone))
            self.handle = nil
        }
    }

    /// Length includes the report ID byte for numbered reports, as in Windows HID buffers.
    public func getFeatureReport(reportID: UInt8, length: Int) throws -> [UInt8] {
        try Self.validateLength(length, maximum: device.maxFeatureReportSize)
        lock.lock()
        defer { lock.unlock() }
        guard let handle else { throw F75HIDError.closed }
        var bytes = [UInt8](repeating: 0, count: length)
        bytes[0] = reportID
        var actualLength = length
        let status = bytes.withUnsafeMutableBufferPointer {
            IOHIDDeviceGetReport(handle, kIOHIDReportTypeFeature, CFIndex(reportID), $0.baseAddress!, &actualLength)
        }
        guard status == kIOReturnSuccess else { throw F75HIDError.io("Read feature report", status) }
        guard actualLength > 0, actualLength <= length else {
            throw F75HIDError.invalidReport("device returned an invalid length (\(actualLength))")
        }
        let result = Array(bytes.prefix(actualLength))
        if reportID != 0, result.first != reportID {
            throw F75HIDError.invalidReport("device returned a different report ID")
        }
        return result
    }

    /// Bytes include the report ID at index zero for numbered reports. No padding or truncation is applied.
    public func setFeatureReport(reportID: UInt8, bytes: [UInt8]) throws {
        try Self.validateReport(reportID: reportID, bytes: bytes, maximum: device.maxFeatureReportSize)
        lock.lock()
        defer { lock.unlock() }
        guard let handle else { throw F75HIDError.closed }
        let status = bytes.withUnsafeBufferPointer {
            IOHIDDeviceSetReport(handle, kIOHIDReportTypeFeature, CFIndex(reportID), $0.baseAddress!, $0.count)
        }
        guard status == kIOReturnSuccess else { throw F75HIDError.io("Write feature report", status) }
    }

    static func validateLength(_ length: Int, maximum: Int) throws {
        guard maximum > 0, length > 0, length <= maximum else {
            throw F75HIDError.invalidReport("length \(length) must be between 1 and the interface maximum \(maximum)")
        }
    }

    static func validateReport(reportID: UInt8, bytes: [UInt8], maximum: Int) throws {
        try validateLength(bytes.count, maximum: maximum)
        guard reportID == 0 || bytes.first == reportID else {
            throw F75HIDError.invalidReport("the first byte must equal report ID \(reportID)")
        }
    }

    private static func matchingDevices(vendorID: Int?, productID: Int?, usagePage: Int?, usage: Int?) -> [IOHIDDevice] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        var matching: [String: Int] = [:]
        matching[kIOHIDVendorIDKey] = vendorID
        matching[kIOHIDProductIDKey] = productID
        matching[kIOHIDPrimaryUsagePageKey] = usagePage
        matching[kIOHIDPrimaryUsageKey] = usage
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        return Array((IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? [])
    }
}
