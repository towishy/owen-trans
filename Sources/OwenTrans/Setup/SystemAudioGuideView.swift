import SwiftUI

/// 시스템 오디오(BlackHole) 설정을 그림과 함께 단계별로 안내하는 가이드.
///
/// 초보자도 따라 할 수 있도록 Audio MIDI 설정·사운드 출력·입력 선택 화면을
/// 단순화한 mock 일러스트로 보여준다.
struct SystemAudioGuideView: View {
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("시스템 오디오 설정 가이드")
                    .font(.nanum(17, weight: .extraBold))
                Spacer()
                Button { onClose() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("브라우저·YouTube 영어 소리를 번역하려면, 시스템 소리를 BlackHole 로 흘려보낸 뒤 OwenTrans 가 그 소리를 듣게 합니다. 아래 5단계를 따라 하세요.")
                        .font(.nanum(12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    step(1, "BlackHole 설치", "마법사의 ‘시스템 오디오 캡처 장치’ 설치 버튼을 누르고 터미널에서 암호를 입력합니다.") {
                        terminalMock()
                    }

                    step(2, "Audio MIDI 설정에서 ‘다중 출력 기기’ 생성", "Audio MIDI 설정 좌측 하단의 ‘+’ → ‘다중 출력 기기 생성’을 선택합니다.") {
                        plusMenuMock()
                    }

                    step(3, "스피커 + BlackHole 둘 다 체크", "새로 만든 다중 출력 기기에서 ‘MacBook Pro 스피커’와 ‘BlackHole 2ch’를 모두 체크합니다.") {
                        multiOutputMock()
                    }

                    step(4, "시스템 출력을 ‘다중 출력 기기’로", "메뉴바 소리 아이콘 또는 시스템 설정 → 사운드 → 출력에서 ‘다중 출력 기기’를 선택합니다. (소리는 스피커로도 들립니다)") {
                        soundOutputMock()
                    }

                    step(5, "OwenTrans 입력 = BlackHole 2ch", "환경설정 → 음성 입력 장치에서 ‘BlackHole 2ch · 시스템 오디오’를 선택하면 끝! 번역을 시작하고 영어 영상을 재생하세요.") {
                        inputPickerMock()
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 560, height: 620)
    }

    // MARK: - 단계 레이아웃

    private func step<Illustration: View>(_ number: Int, _ title: String, _ detail: String,
                                          @ViewBuilder illustration: () -> Illustration) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text("\(number)")
                    .font(.nanum(13, weight: .extraBold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.accentColor))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.nanum(14, weight: .bold))
                    Text(detail).font(.nanum(12, weight: .light))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            illustration()
                .padding(.leading, 34)
        }
    }

    // MARK: - Mock 일러스트

    private func mockWindow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Circle().fill(Color(red: 1, green: 0.37, blue: 0.35)).frame(width: 9, height: 9)
                Circle().fill(Color(red: 1, green: 0.74, blue: 0.18)).frame(width: 9, height: 9)
                Circle().fill(Color(red: 0.25, green: 0.79, blue: 0.25)).frame(width: 9, height: 9)
                Text(title).font(.nanum(10, weight: .bold)).foregroundStyle(.secondary)
                    .padding(.leading, 6)
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Color.gray.opacity(0.12))
            content()
                .padding(10)
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .windowBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.secondary.opacity(0.25), lineWidth: 1))
    }

    private func terminalMock() -> some View {
        mockWindow("터미널") {
            VStack(alignment: .leading, spacing: 4) {
                Text("$ brew install blackhole-2ch")
                    .font(.system(size: 11, design: .monospaced))
                Text("Password: ••••••••")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("🍺  blackhole-2ch was successfully installed!")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.green)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func plusMenuMock() -> some View {
        mockWindow("오디오 장치") {
            HStack(alignment: .bottom, spacing: 12) {
                VStack(spacing: 6) {
                    deviceRow("speaker.wave.2.fill", "MacBook Pro 스피커")
                    deviceRow("mic.fill", "MacBook Pro 마이크")
                    // + 버튼 + 팝업 메뉴
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 24, height: 24)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.18)))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor, lineWidth: 1.5))
                        VStack(alignment: .leading, spacing: 0) {
                            menuItem("결합 기기 생성", highlighted: false)
                            menuItem("다중 출력 기기 생성", highlighted: true)
                        }
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .windowBackgroundColor)))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.secondary.opacity(0.25), lineWidth: 1))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func multiOutputMock() -> some View {
        mockWindow("다중 출력 기기") {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("사용").font(.nanum(10, weight: .bold)).frame(width: 36, alignment: .leading)
                    Text("오디오 기기").font(.nanum(10, weight: .bold))
                    Spacer()
                }
                .foregroundStyle(.secondary)
                checkRow("BlackHole 2ch", checked: true)
                checkRow("MacBook Pro 스피커", checked: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func soundOutputMock() -> some View {
        mockWindow("사운드 — 출력") {
            VStack(alignment: .leading, spacing: 6) {
                selectableRow("speaker.wave.2.fill", "MacBook Pro 스피커", selected: false)
                selectableRow("rectangle.3.group.fill", "다중 출력 기기", selected: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func inputPickerMock() -> some View {
        mockWindow("OwenTrans 환경설정 — 음성 입력 장치") {
            VStack(alignment: .leading, spacing: 6) {
                selectableRow("desktopcomputer", "시스템 기본 입력", selected: false)
                selectableRow("waveform", "BlackHole 2ch · 시스템 오디오", selected: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 작은 부품

    private func deviceRow(_ icon: String, _ name: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 18)
            Text(name).font(.nanum(11))
            Spacer()
        }
    }

    private func menuItem(_ text: String, highlighted: Bool) -> some View {
        Text(text)
            .font(.nanum(11, weight: highlighted ? .bold : .regular))
            .foregroundStyle(highlighted ? .white : .primary)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(highlighted ? Color.accentColor : Color.clear)
    }

    private func checkRow(_ name: String, checked: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: checked ? "checkmark.square.fill" : "square")
                .foregroundStyle(checked ? Color.accentColor : .secondary)
                .frame(width: 36, alignment: .leading)
            Text(name).font(.nanum(11))
            Spacer()
        }
    }

    private func selectableRow(_ icon: String, _ name: String, selected: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(selected ? Color.accentColor : .secondary).frame(width: 18)
            Text(name).font(.nanum(11, weight: selected ? .bold : .regular))
            Spacer()
            if selected {
                Image(systemName: "checkmark").foregroundStyle(Color.accentColor).font(.system(size: 11, weight: .bold))
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 6).fill(selected ? Color.accentColor.opacity(0.12) : Color.clear))
    }
}
