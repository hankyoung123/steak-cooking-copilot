import XCTest

final class LocalizationTests: XCTestCase {
    func testEnglishIsDevelopmentLanguageAndSimplifiedChineseIsAvailable() {
        XCTAssertEqual(Bundle.main.developmentLocalization, "en")
        XCTAssertTrue(Bundle.main.localizations.contains("zh-Hans"))
        XCTAssertNotNil(Bundle.main.path(forResource: "zh-Hans", ofType: "lproj"))
    }

    func testSimplifiedChineseContainsRepresentativeCopy() throws {
        let path = try XCTUnwrap(
            Bundle.main.path(forResource: "zh-Hans", ofType: "lproj")
        )
        let bundle = try XCTUnwrap(Bundle(path: path))

        XCTAssertEqual(
            bundle.localizedString(
                forKey: "Prepare this steak",
                value: nil,
                table: nil
            ),
            "准备这块牛排"
        )
        XCTAssertEqual(
            bundle.localizedString(
                forKey: "TAKE IT OUT",
                value: nil,
                table: nil
            ),
            "立即出锅"
        )
        XCTAssertEqual(
            bundle.localizedString(
                forKey: "This is an estimate, not a live temperature measurement.",
                value: nil,
                table: nil
            ),
            "这是估算时间，并非实时温度测量。"
        )
        XCTAssertEqual(
            bundle.localizedString(
                forKey: "CFBundleDisplayName",
                value: nil,
                table: "InfoPlist"
            ),
            "完美牛排"
        )
    }
}
