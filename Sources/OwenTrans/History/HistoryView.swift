import SwiftUI
import AppKit

/// 저장된 번역 기록(Markdown)을 열람하는 뷰.
struct HistoryView: View {
    @State private var files: [URL] = []
    @State private var selected: URL?
    @State private var content: String = ""
    @State private var searchText: String = ""

    var body: some View {
        HSplitView {
            // 좌측: 파일 목록
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("번역 기록").font(.nanum(13, weight: .extraBold))
                    Spacer()
                    Button { reload() } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.plain)
                }
                .padding(10)
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.system(size: 11))
                    TextField("검색(파일명·내용)", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.nanum(12))
                }
                .padding(.horizontal, 10).padding(.bottom, 8)
                Divider()
                if filteredFiles.isEmpty {
                    Text(searchText.isEmpty ? "저장된 기록이 없습니다." : "검색 결과가 없습니다.")
                        .font(.nanum(12)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredFiles, id: \.self, selection: $selected) { url in
                        Text(displayName(url))
                            .font(.nanum(12))
                            .tag(url)
                    }
                    .listStyle(.sidebar)
                }
            }
            .frame(minWidth: 220, maxWidth: 300)

            // 우측: 본문
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(selected.map(displayName) ?? "기록 선택")
                        .font(.nanum(12, weight: .bold))
                        .lineLimit(1)
                    Spacer()
                    if let selected {
                        Button { NSWorkspace.shared.activateFileViewerSelecting([selected]) } label: {
                            Text("Finder에서 보기").font(.nanum(11))
                        }
                    }
                }
                .padding(10)
                Divider()
                ScrollView {
                    Text(content.isEmpty ? "왼쪽에서 기록을 선택하세요." : content)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(content.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(12)
                }
            }
            .frame(minWidth: 360)
        }
        .frame(width: 720, height: 480)
        .onAppear(perform: reload)
        .onChange(of: selected) { _, newValue in
            content = (newValue.flatMap { try? String(contentsOf: $0, encoding: .utf8) }) ?? ""
        }
    }

    private func reload() {
        let folder = AppSettings.shared.resolvedSaveFolderURL
        let items = (try? FileManager.default.contentsOfDirectory(at: folder,
                                                                  includingPropertiesForKeys: [.contentModificationDateKey],
                                                                  options: [.skipsHiddenFiles])) ?? []
        files = items
            .filter { $0.lastPathComponent.hasPrefix("OwenTrans-번역기록-") && $0.pathExtension == "md" }
            .sorted { lhs, rhs in
                let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                return l > r
            }
        if selected == nil { selected = files.first }
    }

    private func displayName(_ url: URL) -> String {
        url.lastPathComponent
            .replacingOccurrences(of: "OwenTrans-번역기록-", with: "")
            .replacingOccurrences(of: ".md", with: "")
    }

    /// 검색어로 필터링한 파일 목록(파일명 또는 본문 내용 매칭).
    private var filteredFiles: [URL] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return files }
        return files.filter { url in
            if url.lastPathComponent.localizedCaseInsensitiveContains(query) { return true }
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                return text.localizedCaseInsensitiveContains(query)
            }
            return false
        }
    }
}
