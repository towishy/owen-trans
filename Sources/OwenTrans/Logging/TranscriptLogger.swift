import Foundation

/// 번역 세션을 Markdown 문서로 기록한다.
///
/// 세션 시작 시 저장 폴더에 `OwenTrans-번역기록-YYYYMMDD-HHmmss.md` 파일을 만들고,
/// 번역 결과가 확정될 때마다 타임스탬프와 함께 원문/번역을 덧붙인다.
/// 파일 I/O 는 직렬 큐에서 처리해 메인 스레드를 막지 않는다.
final class TranscriptLogger {

    private let queue = DispatchQueue(label: "com.towishy.owen-trans.transcript-logger")
    private var fileURL: URL?

    private let fileStampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f
    }()

    private let humanFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    /// 현재 세션 파일 경로(없으면 nil).
    var currentFileURL: URL? {
        queue.sync { fileURL }
    }

    /// 새 기록 세션을 시작한다.
    func startSession(folder: URL, modelName: String) {
        let now = Date()
        queue.async {
            let fm = FileManager.default
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)

            let name = "OwenTrans-번역기록-\(self.fileStampFormatter.string(from: now)).md"
            let url = folder.appendingPathComponent(name)

            let header = """
            # OwenTrans 번역 기록

            - 시작: \(self.humanFormatter.string(from: now))
            - 모델: \(modelName)


            """
            try? header.write(to: url, atomically: true, encoding: .utf8)
            self.fileURL = url
        }
    }

    /// 확정된 번역 한 건을 덧붙인다.
    func append(original: String, korean: String) {
        let now = Date()
        queue.async {
            guard let url = self.fileURL else { return }
            var block = "## \(self.timeFormatter.string(from: now))\n\n"
            let trimmedOriginal = original.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedOriginal.isEmpty {
                block += "- 🇺🇸 \(trimmedOriginal)\n"
            }
            block += "- 🇰🇷 \(korean.trimmingCharacters(in: .whitespacesAndNewlines))\n\n"
            self.appendString(block, to: url)
        }
    }

    /// 세션을 마무리하고 파일을 닫는다.
    func endSession() {
        let now = Date()
        queue.async {
            guard let url = self.fileURL else { return }
            let footer = "---\n\n- 종료: \(self.humanFormatter.string(from: now))\n"
            self.appendString(footer, to: url)
            self.fileURL = nil
        }
    }

    // 큐 내부에서만 호출.
    private func appendString(_ text: String, to url: URL) {
        guard let data = text.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(data)
        } else {
            // 파일이 없으면 새로 생성.
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
