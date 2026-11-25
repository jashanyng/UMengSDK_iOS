#!/usr/bin/env bash
# 校验 Package.swift 声明的友盟官方制品与本包可用性。
#
# 用法：scripts/verify.sh [--skip-build]
#   1. 校验 SwiftPM 清单可解析；
#   2. 逐个下载 Package.swift 声明的官方制品，核对 SHA-256、目录结构、
#      xcframework 代码签名、各切片的 PrivacyInfo.xcprivacy 与版本号；
#   3. 编译并链接冒烟测试 bundle（iOS Simulator），证明产品可被正常链接。
set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd)
manifest="$repository_root/Package.swift"
skip_build=false

for argument in "$@"; do
    case "$argument" in
        --skip-build) skip_build=true ;;
        -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
        *) printf 'error: 未知参数 %s\n' "$argument" >&2; exit 2 ;;
    esac
done

read_constant() {
    # 从 Package.swift 读取 `let <name> = "<value>"` 形式的常量。
    local value
    value=$(sed -n "s/^let $1 = \"\(.*\)\"$/\1/p" "$manifest")
    if [ -z "$value" ]; then
        printf 'error: Package.swift 中缺少常量 %s\n' "$1" >&2
        exit 1
    fi
    printf '%s' "$value"
}

base_url=$(read_constant officialArtifactBaseURL)
work_directory=$(mktemp -d)
trap 'rm -rf "$work_directory"' EXIT

step() { printf '\n==> %s\n' "$1"; }

step 'SwiftPM 清单'
swift package --package-path "$repository_root" dump-package >/dev/null
echo 'ok'

verify_component() {
    local name=$1 version=$2 expected_checksum=$3
    local url="$base_url/$name/${name}_$version.zip"
    local archive="$work_directory/${name}_$version.zip"
    local extract_directory="$work_directory/$name"

    step "官方制品 $name $version"
    echo "$url"
    curl --fail --silent --show-error --location --retry 3 --output "$archive" "$url"

    local actual_checksum
    actual_checksum=$(swift package --package-path "$repository_root" compute-checksum "$archive")
    if [ "$actual_checksum" != "$expected_checksum" ]; then
        printf 'error: %s 校验值不一致\n  声明：%s\n  实际：%s\n' \
            "$name" "$expected_checksum" "$actual_checksum" >&2
        exit 1
    fi
    echo "checksum ok: $actual_checksum"

    mkdir -p "$extract_directory"
    unzip -q "$archive" -d "$extract_directory"
    local xcframework="$extract_directory/${name}_$version/$name.xcframework"
    if [ ! -d "$xcframework" ]; then
        printf 'error: 未找到 %s（官方压缩包结构可能已变化）\n' "${name}_$version/$name.xcframework" >&2
        exit 1
    fi

    codesign --verify "$xcframework"
    echo "codesign ok: $(codesign -dv "$xcframework" 2>&1 | sed -n 's/^TeamIdentifier=//p')"

    local slice_count=0 framework
    for framework in "$xcframework"/*/"$name.framework"; do
        [ -d "$framework" ] || continue
        slice_count=$((slice_count + 1))
        local slice
        slice=$(basename "$(dirname "$framework")")
        if [ ! -f "$framework/PrivacyInfo.xcprivacy" ]; then
            printf 'error: %s 切片 %s 缺少 PrivacyInfo.xcprivacy\n' "$name" "$slice" >&2
            exit 1
        fi
        local bundle_version
        bundle_version=$(plutil -extract CFBundleShortVersionString raw "$framework/Info.plist")
        if [ "$bundle_version" != "$version" ]; then
            printf 'error: %s 切片 %s 版本为 %s，期望 %s\n' "$name" "$slice" "$bundle_version" "$version" >&2
            exit 1
        fi
        echo "slice ok: $slice ($bundle_version, PrivacyInfo.xcprivacy)"
    done
    for required_slice in ios-arm64 ios-arm64_x86_64-simulator; do
        if [ ! -d "$xcframework/$required_slice/$name.framework" ]; then
            printf 'error: %s 缺少切片 %s\n' "$name" "$required_slice" >&2
            exit 1
        fi
    done
    echo "slices: $slice_count"
}

verify_component UMCommon "$(read_constant umCommonVersion)" "$(read_constant umCommonChecksum)"
verify_component UMDevice "$(read_constant umDeviceVersion)" "$(read_constant umDeviceChecksum)"

if [ "$skip_build" = true ]; then
    step '跳过冒烟编译（--skip-build）'
    exit 0
fi

step '冒烟编译与链接（iOS Simulator）'
(
    cd "$repository_root"
    xcodebuild build-for-testing \
        -scheme UMengSDK \
        -destination 'generic/platform=iOS Simulator' \
        -derivedDataPath "$work_directory/DerivedData" \
        -quiet
)
echo 'ok'

step '全部通过'
