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
                forKey: "Start Cooking",
                value: nil,
                table: nil
            ),
            "开始烹饪"
        )
        XCTAssertEqual(
            bundle.localizedString(
                forKey: "Rare",
                value: nil,
                table: nil
            ),
            "一分熟"
        )
        XCTAssertEqual(
            bundle.localizedString(
                forKey: "Medium Rare",
                value: nil,
                table: nil
            ),
            "三分熟"
        )
        XCTAssertEqual(
            bundle.localizedString(
                forKey: "Medium",
                value: nil,
                table: nil
            ),
            "五分熟"
        )
        XCTAssertEqual(
            bundle.localizedString(
                forKey: "Medium Well",
                value: nil,
                table: nil
            ),
            "七分熟"
        )
        XCTAssertEqual(
            bundle.localizedString(
                forKey: "Well Done",
                value: nil,
                table: nil
            ),
            "全熟"
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
