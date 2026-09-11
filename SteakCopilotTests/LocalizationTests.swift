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
                forKey: "Begin Cooking →",
                value: nil,
                table: nil
            ),
            "开始烹饪 →"
        )
        XCTAssertEqual(
            bundle.localizedString(
                forKey: "Fine-tune settings",
                value: nil,
                table: nil
            ),
            "精调设置"
        )
        XCTAssertEqual(
            bundle.localizedString(
                forKey: "View Cook Log",
                value: nil,
                table: nil
            ),
            "查看烹饪记录"
        )
        XCTAssertEqual(
            bundle.localizedString(
                forKey: "Your Cook Log",
                value: nil,
                table: nil
            ),
            "你的烹饪记录"
        )
        XCTAssertEqual(
            bundle.localizedString(
                forKey: "SEAR · SIDE ONE",
                value: nil,
                table: nil
            ),
            "煎制 · 第一面"
        )
        XCTAssertEqual(
            bundle.localizedString(
                forKey: "Check doneness",
                value: nil,
                table: nil
            ),
            "检查熟度"
        )
        let cookingCopy = [
            "Add butter and aromatics.": "加入黄油和香料。",
            "Flip now.": "立即翻面。",
            "Remove from the pan.": "立即出锅。",
            "Sear the fat edge.": "煎制脂肪边。",
            "Settings": "设置",
            "LAST READING": "最后读数",
            "FINISHING": "静置收尾",
            "No thermometer — use timing": "没有温度计—改用计时",
            "Finishing heat": "余温收尾",
            "SESSION ENDED": "本次烹饪已结束",
            "CANCELLED": "已取消",
            "Oil should shimmer and the steak should sizzle immediately on contact.":
                "油面应微微泛光，牛排入锅应立即发出滋滋声。",
            "Carryover heat will finish the center.": "余温会继续加热中心。",
            // The finishing card builds this line with String(format:), so the
            // catalog key has to be the *format* string. It used to be stored
            // with the production numbers already substituted (+1–3°C), so the
            // lookup missed and the Chinese UI silently fell back to English.
            "Expected carryover +%lld–%lld°C": "预计余温升温 +%lld–%lld°C"
        ]
        for (key, translation) in cookingCopy {
            XCTAssertEqual(
                bundle.localizedString(forKey: key, value: nil, table: nil),
                translation,
                "Missing Simplified Chinese translation for \(key)"
            )
        }
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
