import XCTest
@testable import RoyalDashCore

final class H264NalProcessorTests: XCTestCase {
    func testAnnexBParsingFiltersAudAndSei() throws {
        var processor = H264NalProcessor()
        let accessUnit: [UInt8] = [
            0x00, 0x00, 0x01, 0x09, 0xF0,
            0x00, 0x00, 0x00, 0x01, 0x06, 0x05,
            0x00, 0x00, 0x01, 0x65, 0x88, 0x84,
        ]

        let units = try processor.process(accessUnit: accessUnit, format: .annexB)

        XCTAssertEqual(units.map(\.bytes), [
            [0x65, 0x88, 0x84],
        ])
        XCTAssertTrue(units[0].isIdr)
    }

    func testAvccParsingUsesLengthPrefixes() throws {
        var processor = H264NalProcessor()
        let accessUnit: [UInt8] = [
            0x00, 0x00, 0x00, 0x03, 0x41, 0x9A, 0x22,
            0x00, 0x00, 0x00, 0x02, 0x61, 0x10,
        ]

        let units = try processor.process(accessUnit: accessUnit, format: .avcc(lengthSize: 4))

        XCTAssertEqual(units.map(\.bytes), [
            [0x41, 0x9A, 0x22],
            [0x61, 0x10],
        ])
    }

    func testCachesParameterSetsAndPrependsThemBeforeLaterIdr() throws {
        var processor = H264NalProcessor()

        let first = processor.process(nalUnits: [
            [0x67, 0x42, 0x00, 0x1E],
            [0x68, 0xCE, 0x06],
            [0x41, 0x01],
        ])
        XCTAssertEqual(first.map(\.type), [7, 8, 1])
        XCTAssertEqual(processor.cachedSps, [0x67, 0x42, 0x00, 0x1E])
        XCTAssertEqual(processor.cachedPps, [0x68, 0xCE, 0x06])

        let idr = processor.process(nalUnits: [
            [0x65, 0x88],
        ])
        XCTAssertEqual(idr.map(\.bytes), [
            [0x67, 0x42, 0x00, 0x1E],
            [0x68, 0xCE, 0x06],
            [0x65, 0x88],
        ])
    }

    func testDoesNotDuplicateParameterSetsAlreadyInIdrAccessUnit() {
        var processor = H264NalProcessor(
            cachedSps: [0x67, 0xAA],
            cachedPps: [0x68, 0xBB]
        )

        let units = processor.process(nalUnits: [
            [0x67, 0xCC],
            [0x68, 0xDD],
            [0x65, 0x88],
        ])

        XCTAssertEqual(units.map(\.bytes), [
            [0x67, 0xCC],
            [0x68, 0xDD],
            [0x65, 0x88],
        ])
    }

    func testAvccRejectsTruncatedNal() {
        var processor = H264NalProcessor()

        XCTAssertThrowsError(
            try processor.process(
                accessUnit: [0x00, 0x00, 0x00, 0x04, 0x65, 0x88],
                format: .avcc(lengthSize: 4)
            )
        ) { error in
            XCTAssertEqual(
                error as? H264NalProcessorError,
                .truncatedNal(expected: 4, remaining: 2)
            )
        }
    }
}
