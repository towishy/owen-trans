import Foundation
import ServiceManagement

/// 로그인 시 자동 실행(로그인 항목) 관리.
///
/// macOS 13+ 의 `SMAppService.mainApp` 를 사용한다.
/// 설치 위치와 무관하게 앱 자신을 로그인 항목으로 등록/해제할 수 있으며,
/// ‘시스템 설정 > 일반 > 로그인 항목 및 확장 프로그램’에 표시된다.
enum LoginItem {

    /// 현재 로그인 시 자동 실행이 켜져 있는지.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// 자동 실행 등록/해제. 실패 시 오류를 던진다.
    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        }
    }
}
