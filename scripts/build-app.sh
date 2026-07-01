#!/usr/bin/env bash
#
# OwenTrans.app 번들을 조립한다.
# 전체 Xcode 없이 Command Line Tools 만으로 실행 가능한 .app 을 만든다.
# (마이크 / 음성 인식 권한이 동작하려면 Info.plist 가 포함된 .app 번들이 필요하다.)
#
# 사용법:
#   ./scripts/build-app.sh            # release 빌드 + .app 조립 + 서명
#   ./scripts/build-app.sh --run      # 위 + 실행
#   ./scripts/build-app.sh --install  # 위 + /Applications 로 설치(이동)
#   ./scripts/build-app.sh --zip      # 위 + 배포용 zip(dist/OwenTrans-v<버전>-macos-<arch>.zip) 생성
#   ./scripts/build-app.sh --release  # 위 + Developer ID 서명 + Apple 공증 + 스테이플 (타 기기 배포용)
#
# 서명 방식:
#   - keychain 에 "Developer ID Application" 인증서가 있으면 자동으로 hardened runtime 서명.
#   - 없으면 ad-hoc(-) 서명(같은 기기 실행 전용).
#   - SIGN_IDENTITY 환경변수로 서명 ID 를 강제 지정 가능.
#
# 공증(--release) 사전 준비 (1회):
#   xcrun notarytool store-credentials OwenTransNotary \
#     --apple-id "<Apple ID>" --team-id "<Team ID>" --password "<앱 전용 암호>"
#   (프로파일 이름은 NOTARY_PROFILE 환경변수로 변경 가능)

set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="OwenTrans"
CONFIG="release"
DIST="dist"
APP_DIR="${DIST}/${APP_NAME}.app"
MACOS_DIR="${APP_DIR}/Contents/MacOS"
RES_DIR="${APP_DIR}/Contents/Resources"

echo "▶︎ SwiftPM 빌드 (${CONFIG})…"
swift build -c "${CONFIG}"

BIN_PATH="$(swift build -c "${CONFIG}" --show-bin-path)"

echo "▶︎ .app 번들 조립…"
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RES_DIR}"

cp "${BIN_PATH}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
cp "Info.plist" "${APP_DIR}/Contents/Info.plist"

# SwiftPM 리소스 번들(폰트 등) 동봉.
if [ -d "${BIN_PATH}/${APP_NAME}_${APP_NAME}.bundle" ]; then
  cp -R "${BIN_PATH}/${APP_NAME}_${APP_NAME}.bundle" "${RES_DIR}/"
fi

# 앱 아이콘 동봉(있으면).
if [ -f "Resources/AppIcon.icns" ]; then
  cp "Resources/AppIcon.icns" "${RES_DIR}/AppIcon.icns"
fi

# 서명 ID 결정:
#   1) 환경변수 SIGN_IDENTITY 가 있으면 그것을 사용
#   2) 없으면 keychain 의 "Developer ID Application" 인증서를 자동 탐색
#   3) 그래도 없으면 ad-hoc(-) 서명 (같은 기기 실행 전용, 타 기기 배포 불가)
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
if [ -z "${SIGN_IDENTITY}" ]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | awk -F'"' '/Developer ID Application/{print $2; exit}')"
fi

if [ -n "${SIGN_IDENTITY}" ]; then
  echo "▶︎ Developer ID 코드 서명 (hardened runtime): ${SIGN_IDENTITY}"
  # 내부 실행 파일을 먼저 서명한 뒤 번들을 서명한다(공증 요구사항).
  #   --options runtime : hardened runtime (공증 필수)
  #   --timestamp       : 보안 타임스탬프 (공증 필수, 네트워크 필요)
  codesign --force --options runtime --timestamp \
    --entitlements "OwenTrans.entitlements" \
    --sign "${SIGN_IDENTITY}" \
    "${MACOS_DIR}/${APP_NAME}"
  codesign --force --options runtime --timestamp \
    --entitlements "OwenTrans.entitlements" \
    --sign "${SIGN_IDENTITY}" \
    "${APP_DIR}"
  SIGNED_WITH_DEVID=1
else
  echo "▶︎ ad-hoc 코드 서명 (마이크 entitlement 포함) — 같은 기기 실행 전용…"
  codesign --force --deep \
    --sign - \
    --entitlements "OwenTrans.entitlements" \
    "${APP_DIR}"
  SIGNED_WITH_DEVID=0
fi

echo "✓ 완료: ${APP_DIR}"

# 공증에 사용할 keychain 프로파일 이름(기본값). 사전에 아래로 1회 저장 필요:
#   xcrun notarytool store-credentials OwenTransNotary \
#     --apple-id "<Apple ID>" --team-id "<Team ID>" --password "<앱 암호>"
NOTARY_PROFILE="${NOTARY_PROFILE:-OwenTransNotary}"

# 배포용 zip 을 만들고 ZIP_PATH 를 설정한다.
make_zip() {
  # 버전은 최신 git 태그(없으면 Info.plist)에서 추출.
  VERSION="$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')"
  if [ -z "${VERSION}" ]; then
    VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist 2>/dev/null || echo dev)"
  fi
  ARCH="$(uname -m)"
  ZIP_NAME="${APP_NAME}-v${VERSION}-macos-${ARCH}.zip"
  ZIP_PATH="${DIST}/${ZIP_NAME}"
  echo "▶︎ 배포용 zip 생성 (${ZIP_NAME})…"
  rm -f "${ZIP_PATH}"
  # ditto: .app 번들의 서명/리소스 포크를 보존해 압축(zip 명령보다 안전).
  ditto -c -k --sequesterRsrc --keepParent "${APP_DIR}" "${ZIP_PATH}"
  echo "✓ zip: ${ZIP_PATH}"
}

# Apple 공증 제출 → 통과 시 .app 에 티켓 스테이플 → 배포용 zip 재생성.
notarize_and_staple() {
  echo "▶︎ Apple 공증 제출 (프로파일: ${NOTARY_PROFILE})…"
  xcrun notarytool submit "${ZIP_PATH}" \
    --keychain-profile "${NOTARY_PROFILE}" \
    --wait
  echo "▶︎ 공증 티켓 스테이플…"
  xcrun stapler staple "${APP_DIR}"
  xcrun stapler validate "${APP_DIR}"
  # 스테이플된 .app 으로 배포용 zip 재생성(오프라인에서도 Gatekeeper 통과).
  echo "▶︎ 스테이플된 앱으로 zip 재생성…"
  make_zip
  echo "✓ 공증 완료 및 스테이플: ${APP_DIR}"
}

MODE="${1:-}"

if [[ "${MODE}" == "--zip" ]]; then
  make_zip
fi

if [[ "${MODE}" == "--release" ]]; then
  # 배포용: Developer ID 서명 + zip + 공증 + 스테이플.
  if [[ "${SIGNED_WITH_DEVID}" != "1" ]]; then
    echo "✗ --release 는 Developer ID Application 인증서가 필요합니다." >&2
    echo "  Apple Developer 멤버십으로 인증서를 발급/설치한 뒤 다시 실행하세요." >&2
    exit 1
  fi
  make_zip
  notarize_and_staple
fi

if [[ "${MODE}" == "--install" ]]; then
  TARGET="/Applications/${APP_NAME}.app"
  echo "▶︎ /Applications 로 설치…"
  # 실행 중이면 종료.
  pkill -x "${APP_NAME}" 2>/dev/null || true
  rm -rf "${TARGET}"
  cp -R "${APP_DIR}" "${TARGET}"
  echo "✓ 설치됨: ${TARGET}"
  echo "▶︎ 실행…"
  open "${TARGET}"
elif [[ "${MODE}" == "--run" ]]; then
  echo "▶︎ 실행…"
  open "${APP_DIR}"
fi
