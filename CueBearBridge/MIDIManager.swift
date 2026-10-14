import Foundation
import CoreMIDI

final class MIDIManager {
    private var client = MIDIClientRef()
    private var midiSource = MIDIEndpointRef()
    private var destination = MIDIEndpointRef()

    var onIncomingMIDI: ((Data) -> Void)?

    // v1.2.1: no longer prints on every access (it was called for every MIDI message).
    var source: MIDIEndpointRef {
        return midiSource
    }

    func createVirtualSourceIfNeeded() {
        if client == 0 {
            let result = MIDIClientCreate("CueBearBridge" as CFString, nil, nil, &client)
            if result != noErr {
                print("MIDI Router: Failed to create MIDI client: \(result)")
                return
            }
            print("MIDI Router: MIDI client created")
        }
        if midiSource == 0 {
            let result = MIDISourceCreate(client, "Bear Bridge" as CFString, &midiSource)
            if result != noErr {
                print("MIDI Router: Failed to create MIDI source: \(result)")
                return
            }
            if midiSource == 0 {
                print("MIDI Router: MIDI source creation returned 0 - this is a problem!")
            } else {
                print("MIDI Router: Bear Bridge virtual MIDI source is visible to DAWs (source=\(midiSource))")
            }
        } else {
            print("MIDI Router: MIDI source already exists (source=\(midiSource))")
        }
    }

    func createVirtualDestinationIfNeeded() {
        if client == 0 {
            MIDIClientCreate("CueBearBridge" as CFString, nil, nil, &client)
        }
        if destination == 0 {
            MIDIDestinationCreate(client, "Bear Bridge" as CFString, { (packetList, refCon, connRefCon) in
                guard let refCon = refCon else {
                    Logger.shared.log("MIDIManager: Null refCon in notification")
                    return
                }
                let midiManager = Unmanaged<MIDIManager>.fromOpaque(refCon).takeUnretainedValue()
                midiManager.handleIncomingMIDI(packetList)
            }, Unmanaged.passUnretained(self).toOpaque(), &destination)
            print("MIDI Router: Bear Bridge virtual MIDI destination is visible to DAWs")
        }
    }

    /// v1.2.1: walks the packet list in place. The old loop copied the first packet into a
    /// local variable and called MIDIPacketNext on the copy, which reads past it whenever the
    /// DAW sends more than one packet at a time. It also only read the first message in each
    /// packet; a packet can hold several.
    private func handleIncomingMIDI(_ packetList: UnsafePointer<MIDIPacketList>) {
        for packetPointer in packetList.unsafeSequence() {
            let length = min(Int(packetPointer.pointee.length), 256)
            let bytes: [UInt8] = withUnsafeBytes(of: packetPointer.pointee.data) { raw in
                Array(raw.prefix(length))
            }

            var index = 0
            while index < bytes.count {
                let status = bytes[index]
                guard status & 0x80 != 0 else { index += 1; continue }   // skip stray data bytes
                let messageLength: Int
                switch status & 0xF0 {
                case 0x80, 0x90, 0xA0, 0xB0, 0xE0: messageLength = 3
                case 0xC0, 0xD0: messageLength = 2
                default: messageLength = 0   // SysEx and system messages are not forwarded
                }
                guard messageLength > 0, index + messageLength <= bytes.count else { break }

                let message = Data(bytes[index..<(index + messageLength)])
                index += messageLength

                let jsonData = convertMIDIToJSON(message)
                guard !jsonData.isEmpty else { continue }
                DispatchQueue.main.async {
                    self.onIncomingMIDI?(jsonData)
                }
            }
        }
    }

    private func convertMIDIToJSON(_ midiData: Data) -> Data {
        guard midiData.count >= 3 else { return Data() }

        let bytes = Array(midiData)
        let status = bytes[0]
        let data1 = bytes[1]
        let data2 = bytes[2]

        let messageType = status & 0xF0
        let channel = Int(status & 0x0F)

        var jsonDict: [String: Any] = [:]

        switch messageType {
        case 0xB0: // Control Change (CC)
            jsonDict["type"] = "midi_cc"
            jsonDict["channel"] = channel
            jsonDict["cc"] = data1
            jsonDict["value"] = data2

        case 0x90: // Note On
            jsonDict["type"] = "midi_note"
            jsonDict["channel"] = channel
            jsonDict["note"] = data1
            jsonDict["velocity"] = data2

        case 0x80: // Note Off
            jsonDict["type"] = "midi_note"
            jsonDict["channel"] = channel
            jsonDict["note"] = data1
            jsonDict["velocity"] = 0

        default:
            return Data()
        }

        do {
            return try JSONSerialization.data(withJSONObject: jsonDict)
        } catch {
            print("MIDI Router: Failed to convert MIDI to JSON: \(error)")
            return Data()
        }
    }

    func sendTestCC() {
        guard midiSource != 0 else {
            print("MIDI Router: Cannot send test CC - MIDI source not initialized")
            return
        }

        var packet = MIDIPacket()
        packet.timeStamp = 0
        packet.length = 3
        packet.data.0 = 0xB0  // CC on ch 1
        packet.data.1 = 0x01  // ModWheel
        packet.data.2 = 0x40  // 64

        var list = MIDIPacketList(numPackets: 1, packet: packet)
        let result = MIDIReceived(midiSource, &list)

        if result == noErr {
            print("MIDI Router: Test MIDI message sent - check your DAW for 'Bear Bridge'")
        } else {
            print("MIDI Router: Failed to send test MIDI message: error=\(result)")
        }
    }

    // MARK: - Cleanup Methods

    func cleanup() {
        if midiSource != 0 {
            let result = MIDIEndpointDispose(midiSource)
            if result != noErr {
                print("MIDI Router: Failed to remove MIDI source: \(result)")
            }
            midiSource = 0
        }

        if destination != 0 {
            let result = MIDIEndpointDispose(destination)
            if result != noErr {
                print("MIDI Router: Failed to remove MIDI destination: \(result)")
            }
            destination = 0
        }

        if client != 0 {
            let result = MIDIClientDispose(client)
            if result != noErr {
                print("MIDI Router: Failed to dispose MIDI client: \(result)")
            }
            client = 0
        }

        print("MIDI Router: Cleanup completed")
    }

    deinit {
        cleanup()
    }
}
