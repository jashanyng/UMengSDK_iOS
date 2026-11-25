import UMCommon
import XCTest

/// 冒烟测试：只要测试 bundle 能完成编译与链接，即证明官方制品可被解析、
/// 模块可导入、系统库链接声明完整。测试本身不初始化友盟，也不发起网络请求。
final class UMCommonSmokeTests: XCTestCase {
    func testPublicClassesAreLinked() {
        XCTAssertNotNil(NSClassFromString(NSStringFromClass(UMConfigure.self)))
        XCTAssertNotNil(NSClassFromString(NSStringFromClass(MobClick.self)))
    }
}
