import Foundation
import CoreMIDI

final class MIDIManager {
    private var client = MIDIClientRef()
    private var midiSource = MIDIEndpointRef()
    private var destination = MIDIEndpointRef()
    
    var onIncomingMIDI: ((Data) -> Void)?
    
    var source: MIDIEndpointRef {
        print("🎹 MIDI Router: Getting source value: \(midiSource)")
        return midiSource
    }

    func createVirtualSourceIfNeeded() {
        if client == 0 {
            let result = MIDIClientCreate("CueBearBridge" as CFString, nil, nil, &client)
            if result != noErr {
                print("🎹 MIDI Router: ❌ Failed to create MIDI client: \(result)")
                return
            }
            print("🎹 MIDI Router: ✅ MIDI client created")
        }
        if midiSource == 0 {
            let result = MIDISourceCreate(client, "Bear Bridge" as CFString, &midiSource)
            if result != noErr {
                print("🎹 MIDI Router: ❌ Failed to create MIDI source: \(result)")
                return
            }
            print("🎹 MIDI Router: ✅ Bear Bridge virtual MIDI source is visible to DAWs! (source=\(midiSource))")
            
            // Verify the source was created successfully
            if midiSource == 0 {
                print("🎹 MIDI Router: ❌ MIDI source creation returned 0 - this is a problem!")
            } else {
                print("🎹 MIDI Router: ✅ MIDI source verified: \(midiSource)")
            }
        } else {
            print("🎹 MIDI Router: ✅ MIDI source already exists (source=\(midiSource))")
        }
    }
    
    func createVirtualDestinationIfNeeded() {
        if client == 0 {
            MIDIClientCreate("CueBearBridge" as CFString, nil, nil, &client)
        }
        if destination == 0 {
            MIDIDestinationCreate(client, "Bear Bridge" as CFString, { (packetList, refCon, connRefCon) in
                guard let refCon = refCon else {
                    Logger.shared.log("🎹 MIDIManager: Null refCon in notification")
                    return
                }
                let midiManager = Unmanaged<MIDIManager>.fromOpaque(refCon).takeUnretainedValue()
                midiManager.handleIncomingMIDI(packetList)
            }, Unmanaged.passUnretained(self).toOpaque(), &destination)
            print("🎹 MIDI Router: ✅ Bear Bridge virtual MIDI destination is visible to DAWs!")
        }
    }
    
    private func handleIncomingMIDI(_ packetList: UnsafePointer<MIDIPacketList>) {
        let numPackets = Int(packetList.pointee.numPackets)
        var packet = packetList.pointee.packet

        // Iterate through all packets in the packet list
        for i in 0..<numPackets {
            let data = Data(bytes: &packet.data, count: Int(packet.length))

            // Convert raw MIDI data to JSON format for iPad
            let jsonData = convertMIDIToJSON(data)

            DispatchQueue.main.async {
                self.onIncomingMIDI?(jsonData)
            }

            // Move to the next packet if there are more packets
            if i < numPackets - 1 {
                packet = MIDIPacketNext(&packet).pointee
            }
        }
    }
    
    private func convertMIDIToJSON(_ midiData: Data) -> Data {
        guard midiData.count >= 3 else { return Data() }
        
        let bytes = Array(midiData)
        let status = bytes[0]
        let data1 = bytes[1]
        let data2 = bytes[2]
        
        // Parse MIDI message type and channel
        let messageType = status & 0xF0
        let channel = Int(status & 0x0F)
        
        var jsonDict: [String: Any] = [:]
        
        switch messageType {
        case 0xB0: // Control Change (CC)
            jsonDict["type"] = "midi_cc"
            jsonDict["channel"] = channel
            jsonDict["cc"] = data1
            jsonDict["value"] = data2
            print("🎹 MIDI Router: Received CC from DAW: ch=\(channel) cc=\(data1) val=\(data2)")
            
        case 0x90: // Note On
            jsonDict["type"] = "midi_note"
            jsonDict["channel"] = channel
            jsonDict["note"] = data1
            jsonDict["velocity"] = data2
            print("🎹 MIDI Router: Received Note On from DAW: ch=\(channel) note=\(data1) vel=\(data2)")
            
        case 0x80: // Note Off
            jsonDict["type"] = "midi_note"
            jsonDict["channel"] = channel
            jsonDict["note"] = data1
            jsonDict["velocity"] = 0 // Note off
            print("🎹 MIDI Router: Received Note Off from DAW: ch=\(channel) note=\(data1)")
            
        default:
            print("🎹 MIDI Router: Unsupported MIDI message type: 0x\(String(messageType, radix: 16))")
            return Data()
        }
        
        do {
            return try JSONSerialization.data(withJSONObject: jsonDict)
        } catch {
            print("🎹 MIDI Router: Failed to convert MIDI to JSON: \(error)")
            return Data()
        }
    }

    func sendTestCC() {
        guard midiSource != 0 else { 
            print("🎹 MIDI Router: ❌ Cannot send test CC - MIDI source not initialized")
            return 
        }
        
        print("🎹 MIDI Router: Sending test MIDI CC...")
        
        var packet = MIDIPacket()
        packet.timeStamp = 0
        packet.length = 3
        packet.data.0 = 0xB0  // CC on ch 1
        packet.data.1 = 0x01  // ModWheel
        packet.data.2 = 0x40  // 64

        var list = MIDIPacketList(numPackets: 1, packet: packet)
        let result = MIDIReceived(midiSource, &list)
        
        if result == noErr {
            print("🎹 MIDI Router: ✅ Test MIDI message sent successfully - check your DAW for 'Bear Bridge'")
        } else {
            print("🎹 MIDI Router: ❌ Failed to send test MIDI message: error=\(result)")
        }
    }
    
    // MARK: - Cleanup Methods
    
    func cleanup() {
        print("🎹 MIDI Router: Starting cleanup of virtual MIDI devices...")
        
        // Remove virtual MIDI source
        if midiSource != 0 {
            let result = MIDIEndpointDispose(midiSource)
            if result == noErr {
                print("🎹 MIDI Router: ✅ Virtual MIDI source 'Bear Bridge' removed")
            } else {
                print("🎹 MIDI Router: ❌ Failed to remove MIDI source: \(result)")
            }
            midiSource = 0
        }
        
        // Remove virtual MIDI destination
        if destination != 0 {
            let result = MIDIEndpointDispose(destination)
            if result == noErr {
                print("🎹 MIDI Router: ✅ Virtual MIDI destination 'Bear Bridge' removed")
            } else {
                print("🎹 MIDI Router: ❌ Failed to remove MIDI destination: \(result)")
            }
            destination = 0
        }
        
        // Dispose MIDI client
        if client != 0 {
            let result = MIDIClientDispose(client)
            if result == noErr {
                print("🎹 MIDI Router: ✅ MIDI client disposed")
            } else {
                print("🎹 MIDI Router: ❌ Failed to dispose MIDI client: \(result)")
            }
            client = 0
        }
        
        print("🎹 MIDI Router: Cleanup completed - virtual MIDI devices should no longer be visible")
    }
    
    deinit {
        print("🎹 MIDI Router: deinit called - cleaning up virtual MIDI devices")
        cleanup()
    }
}
