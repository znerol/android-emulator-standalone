#!/bin/sh
# Build Android Emulator Standalone App from an existing AVD
#
# Usage: build-app.sh AVD_NAME [ANDROID_SDK_ROOT]

set -eux

CAT=/bin/cat
CHMOD=/bin/chmod
CP=/bin/cp
FIND=/usr/bin/find
LN=/bin/ln
MKDIR=/bin/mkdir
MKTEMP=/usr/bin/mktemp
PLISTBUDDY=/usr/libexec/PlistBuddy
SED=/usr/bin/sed
XARGS=/usr/bin/xargs
YES=/usr/bin/yes

usage() {
  echo "Usage: ${0} AVD_NAME [ANDROID_SDK_ROOT]"
}

get_tag() {
  ${SED} -n 's/^[\.s]*tag\.id[\.s]*=[\.s]*//p' "${1}"
}

get_abi() {
  ${SED} -n 's/^[\.s]*abi\.type[\.s]*=[\.s]*//p' "${1}"
}

get_target() {
  ${SED} -n 's/^[\.s]*target[\.s]*=[\.s]*//p' "${1}"
}

get_display_name() {
  ${SED} -n 's/^[\.s]*avd\.ini\.displayname[\.s]*=[\.s]*//p' "${1}"
}

build_app() {
  AND_SDK="${1}"
  AVD_DIR="${2}"
  AVD_NAME="${3}"
  AVD_INI="${AVD_DIR}/${AVD_NAME}.ini"
  AVD_CONF="${AVD_DIR}/${AVD_NAME}.avd/config.ini"

  TARGET="$(get_target "${AVD_INI}")"
  TAG="$(get_tag "${AVD_CONF}")"
  ABI="$(get_abi "${AVD_CONF}")"
  DISPLAY_NAME="$(get_display_name "${AVD_CONF}")"
  DISPLAY_NAME="${DISPLAY_NAME:-${AVD_NAME}}"

  # Base structure
  DIST_DIR="$(${MKTEMP} -d "./${DISPLAY_NAME}.XXXXXX")"
  ${MKDIR} -p "${DIST_DIR}/Contents/MacOS" "${DIST_DIR}/Contents/Resources/avd"

  # Copy AVD
  ${CP} -R "${AVD_DIR}/${AVD_NAME}.avd" "${DIST_DIR}/Contents/Resources/avd/"

  # Remove paths from ini.
  ${CAT} <<EOF > "${DIST_DIR}/Contents/Resources/avd/${AVD_NAME}.ini"
avd.ini.encoding=UTF-8
target=${TARGET}
EOF

  # Copy script and link executable
  ${CP} android-emulator-standalone "${DIST_DIR}/Contents/MacOS"
  ${LN} -s android-emulator-standalone "${DIST_DIR}/Contents/MacOS/$AVD_NAME"

  # Install required tools and image
  SDK_MGR="${AND_SDK}/cmdline-tools/latest/bin/sdkmanager"

  ${YES} | ${SDK_MGR} --sdk_root="${DIST_DIR}/Contents/Resources/android-sdk" --licenses
  ${SDK_MGR} --sdk_root="${DIST_DIR}/Contents/Resources/android-sdk" "emulator" "platform-tools" "tools" "platforms;${TARGET}" "system-images;${TARGET};${TAG};${ABI}"
  ${FIND} "${DIST_DIR}/Contents/Resources/android-sdk" -perm -0700 -print0 | ${XARGS} -0 ${CHMOD} +x

  # Generate Info.plist
  ${CAT} <<EOF | ${PLISTBUDDY} "${DIST_DIR}/Contents/Info.plist"
Add :CFBundlePackageType string AAPL
Add :CFBundleInfoDictionaryVersion string 6.0
Add :CFBundleName string "${DISPLAY_NAME}"
Add :CFBundleExecutable string "${AVD_NAME}"
Add :CFBundleIdentifier string "com.github.znerol.android-emulator-standalone.${AVD_NAME}"
Add :CFBundleVersion string 1.0
Add :CFBundleGetInfoString string 1.0
Add :CFBundleShortVersionString string 1.0
Save
EOF

}

AVD_BASE="${HOME}/.android/avd"
AVD_SDK="${2:-"${HOME}/Library/Android/sdk"}"
AVD_NAME="${1:-}"
if [ -n "${AVD_NAME}" ] && [ -x "${AVD_SDK}/cmdline-tools/latest/bin/sdkmanager" ] && [ -f "${AVD_BASE}/${AVD_NAME}.ini" ] && [ -f "${AVD_BASE}/${AVD_NAME}.avd/config.ini" ]; then
  build_app "${AVD_SDK}" "${AVD_BASE}" "${AVD_NAME}"
else
  usage
fi
