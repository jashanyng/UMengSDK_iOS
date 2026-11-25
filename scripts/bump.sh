#!/usr/bin/env bash
# 把本包升级到新的友盟基础库版本（人工触发）。
#
# 用法：scripts/bump.sh <UMCommon 版本> [UMDevice 版本]
#   省略 UMDevice 版本时，取 CocoaPods trunk 上 UMDevice 的最新正式版本。
#
# 脚本会：下载官方制品并计算校验值 → 改写 Package.swift 常量 →
# 在 CHANGELOG.md 版本对照表顶部插入一行 → 运行 scripts/verify.sh。
# 提交、打 tag 与发布 Release 由维护者按 README 的“发布新版本”步骤手动完成。
set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd)
manifest="$repository_root/Package.swift"
changelog="$repository_root/CHANGELOG.md"

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    sed -n '2,10p' "$0"
    exit 2
fi

semver_pattern='^[0-9]+\.[0-9]+\.[0-9]+$'
umcommon_version=$1
umdevice_version=${2:-}

latest_trunk_version() {
    curl --fail --silent --show-error --retry 3 "https://trunk.cocoapods.org/api/v1/pods/$1" |
        python3 -c '
import json, re, sys
versions = [v["name"] for v in json.load(sys.stdin)["versions"]]
stable = [v for v in versions if re.fullmatch(r"\d+\.\d+\.\d+", v)]
print(max(stable, key=lambda v: tuple(int(p) for p in v.split("."))))
'
}

if [ -z "$umdevice_version" ]; then
    umdevice_version=$(latest_trunk_version UMDevice)
    echo "UMDevice 未指定，使用 CocoaPods trunk 最新正式版本：$umdevice_version"
fi

for version in "$umcommon_version" "$umdevice_version"; do
    if ! printf '%s' "$version" | grep -Eq "$semver_pattern"; then
        printf 'error: 版本号 %s 不是 MAJOR.MINOR.PATCH 格式\n' "$version" >&2
        exit 2
    fi
done

if git -C "$repository_root" rev-parse --verify --quiet "refs/tags/$umcommon_version" >/dev/null; then
    printf 'error: tag %s 已存在；封装版本发布后不可变（见 docs/adr/0001-package-version-follows-umcommon.md）\n' \
        "$umcommon_version" >&2
    exit 1
fi

base_url=$(sed -n 's/^let officialArtifactBaseURL = "\(.*\)"$/\1/p' "$manifest")
work_directory=$(mktemp -d)
trap 'rm -rf "$work_directory"' EXIT

checksum_of() {
    local name=$1 version=$2
    local archive="$work_directory/${name}_$version.zip"
    curl --fail --silent --show-error --location --retry 3 \
        --output "$archive" "$base_url/$name/${name}_$version.zip"
    swift package --package-path "$repository_root" compute-checksum "$archive"
}

echo "下载官方制品并计算校验值……"
umcommon_checksum=$(checksum_of UMCommon "$umcommon_version")
umdevice_checksum=$(checksum_of UMDevice "$umdevice_version")

replace_constant() {
    local name=$1 value=$2
    if ! grep -q "^let $name = \"" "$manifest"; then
        printf 'error: Package.swift 中缺少常量 %s\n' "$name" >&2
        exit 1
    fi
    sed -i '' "s/^let $name = \".*\"$/let $name = \"$value\"/" "$manifest"
}

replace_constant umCommonVersion "$umcommon_version"
replace_constant umCommonChecksum "$umcommon_checksum"
replace_constant umDeviceVersion "$umdevice_version"
replace_constant umDeviceChecksum "$umdevice_checksum"

release_date=$(date +%Y-%m-%d)
row="| \`$umcommon_version\` | $umcommon_version | $umdevice_version | $release_date |"
marker='<!-- bump.sh 在此行下方插入新版本 -->'
if ! grep -qF "$marker" "$changelog"; then
    printf 'error: CHANGELOG.md 缺少插入标记：%s\n' "$marker" >&2
    exit 1
fi
awk -v marker="$marker" -v row="$row" '{ print } $0 == marker { print row }' \
    "$changelog" >"$work_directory/CHANGELOG.md"
mv "$work_directory/CHANGELOG.md" "$changelog"

echo "已更新 Package.swift 与 CHANGELOG.md：UMCommon $umcommon_version / UMDevice $umdevice_version"
"$repository_root/scripts/verify.sh"

cat <<EOF

下一步（手动）：
  git -C "$repository_root" add Package.swift CHANGELOG.md
  git -C "$repository_root" commit -m "Bump UMCommon to $umcommon_version (UMDevice $umdevice_version)"
  git -C "$repository_root" push origin main
  git -C "$repository_root" tag $umcommon_version && git -C "$repository_root" push origin $umcommon_version
  gh release create $umcommon_version --repo jashanyng/UMengSDK_iOS --title $umcommon_version \\
    --notes "UMCommon $umcommon_version，随附 UMDevice $umdevice_version。"
EOF
