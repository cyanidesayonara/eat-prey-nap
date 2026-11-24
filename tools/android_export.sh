#!/usr/bin/env bash
# Export the signed Android App Bundle (for Google Play) and a sideload APK
# into build/android/. android.yml runs it with a throwaway key.
#
# env: GODOT                  the Godot editor binary (export templates installed)
#      TAG                    v0.1 or v0.1.1: the version name, and the
#                             version code MAJOR*10000 + MINOR*100 + PATCH
#      ANDROID_KEYSTORE_PATH  the keystore file
#      ANDROID_KEY_ALIAS      its key's alias
#      ANDROID_KEY_PASSWORD   the keystore's and the key's password
# ANDROID_HOME and JAVA_HOME must point at the SDK and a JDK 17.
#
# The key reaches Godot through its own GODOT_ANDROID_KEYSTORE_RELEASE_*
# variables, so it is never written into export_presets.cfg. The preset's
# version is edited for the export and put back afterwards.
set -euo pipefail
: "${GODOT:?}" "${TAG:?}" "${ANDROID_KEYSTORE_PATH:?}" "${ANDROID_KEY_ALIAS:?}" "${ANDROID_KEY_PASSWORD:?}"

if [[ ! "$TAG" =~ ^v([0-9]+)\.([0-9]+)(\.([0-9]+))?$ ]]; then
  echo "TAG must look like v0.1 or v0.1.1, got: $TAG"
  exit 1
fi
maj="${BASH_REMATCH[1]}"
min="${BASH_REMATCH[2]}"
pat="${BASH_REMATCH[4]:-0}"
if (( 10#$min > 99 || 10#$pat > 99 )); then
  echo "MINOR and PATCH must stay under 100 for the version code: $TAG"
  exit 1
fi
# the package ID is permanent once published, and is not chosen yet
if grep -q 'unique_name="com.example' export_presets.cfg && [ "${ALLOW_PLACEHOLDER_ID:-0}" != 1 ]; then
  echo "export_presets.cfg still has the placeholder package ID"
  exit 1
fi
name="${TAG#v}"
code=$(( 10#$maj * 10000 + 10#$min * 100 + 10#$pat ))
echo "Android version ${name} (code ${code})"

export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$ANDROID_KEYSTORE_PATH"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$ANDROID_KEY_ALIAS"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$ANDROID_KEY_PASSWORD"

orig="$(mktemp)"
cp export_presets.cfg "$orig"
trap 'cp "$orig" export_presets.cfg; rm -f "$orig"' EXIT

sed -i -E "s/^version\/code=.*/version\/code=${code}/; s/^version\/name=.*/version\/name=\"${name}\"/" export_presets.cfg
grep -q "^version/code=${code}$" export_presets.cfg

# a gradle build exports through the project's android/ template, which is
# not committed. Godot installs it only alongside an export (the flag alone
# starts the editor and waits), so it rides on the first one. Every export
# is time-limited: a hung Godot fails the job instead of eating its timeout.
install=()
if [ ! -d android/build ]; then
  install=(--install-android-build-template)
fi

# no Gradle daemon: Godot's Windows console wrapper waits for every process
# it started, and an idle daemon lives for hours, so the export never returns
export GRADLE_OPTS="${GRADLE_OPTS:-} -Dorg.gradle.daemon=false"

mkdir -p build/android
timeout 1200 "$GODOT" --headless --path . "${install[@]}" --export-release "Android" build/android/EatPreyNap.aab
test -d android/build
test -s build/android/EatPreyNap.aab
# the same build as an APK, to install by hand
sed -i 's/^gradle_build\/export_format=1/gradle_build\/export_format=0/' export_presets.cfg
timeout 1200 "$GODOT" --headless --path . --export-release "Android" build/android/EatPreyNap.apk
test -s build/android/EatPreyNap.apk
ls -l build/android
