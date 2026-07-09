import CoreMedia
import CoreVideo
import Foundation
import RoyalDashCore
import VideoToolbox

enum H264TestPatternEncoderError: LocalizedError {
    case pixelBufferCreationFailed
    case compressionSessionCreationFailed(OSStatus)
    case encodeFailed(OSStatus)
    case timedOut
    case noSampleProduced
    case noDataBuffer
    case parameterSetUnavailable

    var errorDescription: String? {
        switch self {
        case .pixelBufferCreationFailed:
            return "Nao foi possivel criar o frame de teste."
        case .compressionSessionCreationFailed(let status):
            return "Nao foi possivel iniciar o encoder H.264 (\(status))."
        case .encodeFailed(let status):
            return "Falha ao codificar H.264 (\(status))."
        case .timedOut:
            return "Timeout ao gerar frame H.264."
        case .noSampleProduced:
            return "Encoder nao retornou sample H.264."
        case .noDataBuffer:
            return "Frame H.264 sem data buffer."
        case .parameterSetUnavailable:
            return "Encoder nao retornou SPS/PPS H.264."
        }
    }
}

struct H264TestPatternEncoder {
    let width: Int32
    let height: Int32

    init(width: Int32 = 526, height: Int32 = 300) {
        self.width = width
        self.height = height
    }

    func makeRtpPackets() throws -> [[UInt8]] {
        let sample = try encodeSample()
        let nals = try makeNalUnits(from: sample)
        var packets: [[UInt8]] = []
        var packetizer = RtpPacketizer { packet in
            packets.append(packet)
        }

        for (index, nal) in nals.enumerated() {
            packetizer.packetize(
                nal: nal.bytes,
                endOfAccessUnit: index == nals.indices.last,
                wallClockMs: 0
            )
        }

        return packets
    }

    private func encodeSample() throws -> CMSampleBuffer {
        let pixelBuffer = try makePixelBuffer()
        let result = SampleResult()
        let retainedResult = Unmanaged.passRetained(result)
        defer {
            retainedResult.release()
        }

        let callback: VTCompressionOutputCallback = { _, refCon, status, _, sampleBuffer in
            guard let refCon else { return }
            let result = Unmanaged<SampleResult>.fromOpaque(refCon).takeUnretainedValue()
            result.complete(status: status, sampleBuffer: sampleBuffer)
        }

        var session: VTCompressionSession?
        let createStatus = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: width,
            height: height,
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: callback,
            refcon: retainedResult.toOpaque(),
            compressionSessionOut: &session
        )
        guard createStatus == noErr, let session else {
            throw H264TestPatternEncoderError.compressionSessionCreationFailed(createStatus)
        }
        defer {
            VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
            VTCompressionSessionInvalidate(session)
        }

        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Baseline_AutoLevel)

        let keyFrameInterval = 1 as CFNumber
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: keyFrameInterval)

        let bitRate = 350_000 as CFNumber
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: bitRate)
        VTCompressionSessionPrepareToEncodeFrames(session)

        let encodeStatus = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: CMTime(value: 0, timescale: 30),
            duration: CMTime(value: 1, timescale: 30),
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: nil
        )
        guard encodeStatus == noErr else {
            throw H264TestPatternEncoderError.encodeFailed(encodeStatus)
        }
        VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)

        guard result.wait(timeout: .now() + 2) else {
            throw H264TestPatternEncoderError.timedOut
        }
        let snapshot = result.snapshot()
        guard snapshot.status == noErr else {
            throw H264TestPatternEncoderError.encodeFailed(snapshot.status)
        }
        guard let sampleBuffer = snapshot.sampleBuffer else {
            throw H264TestPatternEncoderError.noSampleProduced
        }
        return sampleBuffer
    }

    private func makeNalUnits(from sampleBuffer: CMSampleBuffer) throws -> [H264NalUnit] {
        guard let format = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            throw H264TestPatternEncoderError.parameterSetUnavailable
        }

        let sps = try parameterSet(format: format, index: 0)
        let pps = try parameterSet(format: format, index: 1)

        guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            throw H264TestPatternEncoderError.noDataBuffer
        }

        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(
            dataBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &length,
            dataPointerOut: &dataPointer
        )
        guard status == noErr, let dataPointer else {
            throw H264TestPatternEncoderError.noDataBuffer
        }

        let bytes = Array(UnsafeBufferPointer(start: UnsafeRawPointer(dataPointer).assumingMemoryBound(to: UInt8.self), count: length))
        var processor = H264NalProcessor(cachedSps: sps, cachedPps: pps)
        return try processor.process(accessUnit: bytes, format: .avcc(lengthSize: 4))
    }

    private func parameterSet(format: CMFormatDescription, index: Int) throws -> [UInt8] {
        var pointer: UnsafePointer<UInt8>?
        var size = 0
        var count = 0
        var headerLength: Int32 = 0
        let status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            format,
            parameterSetIndex: index,
            parameterSetPointerOut: &pointer,
            parameterSetSizeOut: &size,
            parameterSetCountOut: &count,
            nalUnitHeaderLengthOut: &headerLength
        )
        guard status == noErr, let pointer, size > 0 else {
            throw H264TestPatternEncoderError.parameterSetUnavailable
        }
        return Array(UnsafeBufferPointer(start: pointer, count: size))
    }

    private func makePixelBuffer() throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(width),
            Int(height),
            kCVPixelFormatType_32BGRA,
            [
                kCVPixelBufferCGImageCompatibilityKey: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            ] as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw H264TestPatternEncoderError.pixelBufferCreationFailed
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw H264TestPatternEncoderError.pixelBufferCreationFailed
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let pointer = baseAddress.assumingMemoryBound(to: UInt8.self)
        let colors: [(b: UInt8, g: UInt8, r: UInt8)] = [
            (0x13, 0xC8, 0xC8),
            (0x1F, 0x7A, 0xEA),
            (0x2F, 0xD1, 0x6B),
            (0xE8, 0xAA, 0x2D),
            (0xCE, 0x4C, 0x79),
        ]

        for y in 0..<Int(height) {
            for x in 0..<Int(width) {
                let color = colors[(x * colors.count) / Int(width)]
                let offset = y * bytesPerRow + x * 4
                pointer[offset] = color.b
                pointer[offset + 1] = color.g
                pointer[offset + 2] = color.r
                pointer[offset + 3] = 0xFF
            }
        }

        return pixelBuffer
    }
}

private final class SampleResult {
    private let semaphore = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var didComplete = false
    private var status: OSStatus = noErr
    private var sampleBuffer: CMSampleBuffer?

    func complete(status: OSStatus, sampleBuffer: CMSampleBuffer?) {
        lock.lock()
        guard !didComplete else {
            lock.unlock()
            return
        }

        didComplete = true
        self.status = status
        self.sampleBuffer = sampleBuffer
        lock.unlock()
        semaphore.signal()
    }

    func wait(timeout: DispatchTime) -> Bool {
        semaphore.wait(timeout: timeout) == .success
    }

    func snapshot() -> (status: OSStatus, sampleBuffer: CMSampleBuffer?) {
        lock.lock()
        defer { lock.unlock() }
        return (status, sampleBuffer)
    }
}
