import AVFoundation
import CoreAudio

/// 오디오 입력 장치 열거 및 선택, 마이크 캡처를 담당한다.
///
/// AVAudioEngine 의 입력 노드에 선택한 CoreAudio 장치를 바인딩하고,
/// 16kHz mono Float PCM 버퍼를 콜백으로 전달한다(STT 입력에 적합).
final class AudioInputManager {

    struct Device: Equatable {
        let id: AudioDeviceID
        let uid: String
        let name: String
    }

    private let engine = AVAudioEngine()
    private var isRunning = false

    /// 마이크 입력 버퍼 콜백.
    var onBuffer: ((AVAudioPCMBuffer, AVAudioTime) -> Void)?

    /// 마이크(TCC) 권한을 명시적으로 요청한다.
    /// macOS 에서는 엔진만 시작하면 권한 프롬프트 없이 무음이 들어올 수 있으므로 필수.
    static func requestMicrophoneAccess(_ completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        default:
            completion(false)
        }
    }

    // MARK: - 장치 열거

    /// 입력 가능한 오디오 장치 목록.
    static func availableInputDevices() -> [Device] {
        var result: [Device] = []

        var size: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject),
                                             &address, 0, nil, &size) == noErr else {
            return result
        }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                         &address, 0, nil, &size, &deviceIDs) == noErr else {
            return result
        }

        for id in deviceIDs where hasInputChannels(id) {
            let uid = stringProperty(id, kAudioDevicePropertyDeviceUID) ?? "\(id)"
            let name = stringProperty(id, kAudioObjectPropertyName) ?? "장치 \(id)"
            result.append(Device(id: id, uid: uid, name: name))
        }
        return result
    }

    private static func hasInputChannels(_ id: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr, size > 0 else {
            return false
        }
        let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(size))
        defer { bufferList.deallocate() }
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, bufferList) == noErr else {
            return false
        }
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        return buffers.contains { $0.mNumberChannels > 0 }
    }

    private static func stringProperty(_ id: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<CFString?>.size)
        var value: CFString? = nil
        let result = withUnsafeMutablePointer(to: &value) { ptr -> OSStatus in
            AudioObjectGetPropertyData(id, &address, 0, nil, &size, ptr)
        }
        guard result == noErr else { return nil }
        return value as String?
    }

    private static func deviceID(forUID uid: String) -> AudioDeviceID? {
        availableInputDevices().first { $0.uid == uid }?.id
    }

    // MARK: - 캡처 제어

    /// 선택한 장치(uid nil 이면 기본)로 캡처 시작.
    func start(deviceUID: String?) throws {
        stop()

        // 선택한 입력 장치를 엔진의 입력 노드에 바인딩.
        if let uid = deviceUID, let deviceID = Self.deviceID(forUID: uid) {
            try setInputDevice(deviceID)
        }

        let input = engine.inputNode
        let inputFormat = input.inputFormat(forBus: 0)

        // STT 친화 포맷(16kHz mono)로 변환.
        guard let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                               sampleRate: 16_000,
                                               channels: 1,
                                               interleaved: false),
              let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioError.formatUnavailable
        }

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, time in
            guard let self else { return }
            let ratio = targetFormat.sampleRate / inputFormat.sampleRate
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
            guard let converted = AVAudioPCMBuffer(pcmFormat: targetFormat,
                                                   frameCapacity: capacity) else { return }
            var consumed = false
            var error: NSError?
            converter.convert(to: converted, error: &error) { _, status in
                if consumed {
                    status.pointee = .noDataNow
                    return nil
                }
                consumed = true
                status.pointee = .haveData
                return buffer
            }
            if error == nil, converted.frameLength > 0 {
                self.onBuffer?(converted, time)
            }
        }

        engine.prepare()
        try engine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }

    private func setInputDevice(_ deviceID: AudioDeviceID) throws {
        guard let audioUnit = engine.inputNode.audioUnit else { return }
        var device = deviceID
        let result = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &device,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        if result != noErr {
            throw AudioError.cannotSetDevice(result)
        }
    }

    enum AudioError: Error {
        case formatUnavailable
        case cannotSetDevice(OSStatus)
    }
}
