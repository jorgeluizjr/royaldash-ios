import Foundation
import RoyalDashCore

@main
struct RoyalDashFakeDashCommand {
    static func main() throws {
        var dash = FakeDashSession()

        print("RoyalDash Fake Dash")
        print("mode=demo transport=offline")

        let authOffer = dash.receiveControl(DashCommands.authRequest())
        print("auth request events: \(authOffer.events)")
        print("auth response packets: \(authOffer.packets.map { $0.hexString() })")

        let keyPacket = try DashCommands.authSendKey(ciphertext: Array(repeating: 0x42, count: 128))
        let authConfirm = dash.receiveControl(keyPacket)
        print("auth key events: \(authConfirm.events)")
        print("auth confirm packets: \(authConfirm.packets.map { $0.hexString() })")

        var rtpPackets: [[UInt8]] = []
        var packetizer = RtpPacketizer(onPacket: { rtpPackets.append($0) })
        packetizer.packetize(nal: [0x65, 0x01, 0x02, 0x03], endOfAccessUnit: true, wallClockMs: 100)

        for packet in rtpPackets {
            print("rtp events: \(dash.receiveRtp(packet).events)")
        }

        print("decoded IDR notify: \(dash.frameDecodedNotify(kind: .idr).hexString())")
        print("button notify: \(dash.buttonEvent(code: 0x06).hexString())")
    }
}
