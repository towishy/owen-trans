import AppKit
import Carbon.HIToolbox

/// 전역 단축키 관리(Carbon RegisterEventHotKey).
///
/// 접근성/입력 모니터링 권한 없이도 동작하는 고전 Carbon 핫키 API를 사용한다.
/// 앱이 백그라운드(메뉴바)에 있어도 단축키가 동작한다.
@MainActor
final class HotKeyCenter {

    static let shared = HotKeyCenter()

    private var handlers: [UInt32: () -> Void] = [:]
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    private init() {
        installEventHandler()
    }

    /// 단축키 등록. modifiers 는 Carbon 마스크(cmdKey, optionKey, controlKey, shiftKey 조합).
    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) -> Bool {
        let id = nextID
        nextID += 1
        handlers[id] = handler

        let hotKeyID = EventHotKeyID(signature: OSType(0x4F574E54), id: id) // 'OWNT'
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                                         GetEventDispatcherTarget(), 0, &ref)
        guard status == noErr, let ref else {
            handlers[id] = nil
            return false
        }
        hotKeyRefs[id] = ref
        return true
    }

    /// 등록된 모든 단축키 해제(재등록 전 호출).
    func unregisterAll() {
        for (_, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        handlers.removeAll()
    }

    private func installEventHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, userData in
            guard let event, let userData else { return noErr }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
            let id = hotKeyID.id
            Task { @MainActor in center.handlers[id]?() }
            return noErr
        }, 1, &spec, selfPtr, &eventHandler)
    }
}
