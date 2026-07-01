#!/usr/bin/env bash
#
# OwenTrans.app 번들을 조립한다.
# 전체 Xcode 없이 Command Line Tools 만으로 실행 가능한 .app 을 만든다.
# (마이크 / 음성 인식 권한이 동작하려면 Info.plist 가 포함된 .app 번들이 필요하다.)
#
# 사용법:
#   ./scripts/build-app.sh            # release 빌드 + .app 조립 + ad-hoc 서명
#   ./scripts/build-app.sh --run      # 위 + 실행
#   ./scripts/build-app.sh --install  # 위 + /Applications 로 설치(이동)
#   ./scripts/build-app.sh --zip      # 위 + 배포용 zip(dist/OwenTrans-v<버전>-macos-<arch>.zip) 생성

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

echo "▶︎ ad-hoc 코드 서명 (마이크 entitlement 포함)…"
codesign --force --deep \
  --sign - \
  --entitlements "OwenTrans.entitlements" \
  "${APP_DIR}"

echo "✓ 완료: ${APP_DIR}"

MODE="${1:-}"

if [[ "${MODE}" == "--zip" ]]; then
  # 배포용 zip 생성. 버전은 최신 git 태그(없으면 Info.plist)에서 추출.
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
