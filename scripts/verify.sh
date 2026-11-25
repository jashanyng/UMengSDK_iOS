#!/usr/bin/env bash
# 校验 CI 工作流安全基线、Package.swift 声明的友盟官方制品与本包可用性。
#
# 用法：scripts/verify.sh [--skip-build]
#   1. 校验 .github/workflows/*.yml 满足 CI 工作流安全基线；
#   2. 校验 SwiftPM 清单可解析；
#   3. 逐个下载 Package.swift 声明的官方制品，核对 SHA-256、目录结构、
#      xcframework 代码签名、各切片的 PrivacyInfo.xcprivacy 与版本号；
#   4. 编译并链接冒烟测试 bundle（iOS Simulator），证明产品可被正常链接。
set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd)
manifest="$repository_root/Package.swift"
skip_build=false

for argument in "$@"; do
    case "$argument" in
        --skip-build) skip_build=true ;;
        -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
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

work_directory=$(mktemp -d)
trap 'rm -rf "$work_directory"' EXIT

step() { printf '\n==> %s\n' "$1"; }

step 'CI 工作流安全基线'
python3 - "$repository_root/.github/workflows" <<'PY'
import glob
import os
import re
import sys

workflows_dir = sys.argv[1]
workflow_files = sorted(
    glob.glob(os.path.join(workflows_dir, "*.yml"))
    + glob.glob(os.path.join(workflows_dir, "*.yaml"))
)
if not workflow_files:
    print(f"error: {workflows_dir} 下未找到工作流文件", file=sys.stderr)
    sys.exit(1)

sha_uses_pattern = re.compile(r"^[^@\s]+@[0-9a-f]{40}$")
top_permissions_empty = re.compile(r"^permissions:\s*\{\s*\}\s*$")
top_permissions_any = re.compile(r"^permissions:\s*(.*)$")
persist_false_pattern = re.compile(r"^\s*persist-credentials:\s*false\s*$")
uses_pattern = re.compile(r"^\s*(?:-\s+)?uses:\s*(.+?)\s*$")
block_scalar_pattern = re.compile(r"^(\s*).*:\s*[|>][+-]?\d*\s*$")

def strip_inline_comment(line: str) -> str:
    in_single = False
    in_double = False
    for index, ch in enumerate(line):
        if ch == "'" and not in_double:
            in_single = not in_single
        elif ch == '"' and not in_single:
            if index == 0 or line[index - 1] != "\\":
                in_double = not in_double
        elif ch == "#" and not in_single and not in_double:
            if index == 0 or line[index - 1].isspace():
                return line[:index]
    return line

failures = []

for path in workflow_files:
    rel = os.path.basename(path)
    with open(path, "r", encoding="utf-8") as fh:
        lines = fh.read().splitlines()

    has_top_permissions_empty = False
    has_other_top_permissions = False
    persist_false_count = 0
    checkout_count = 0
    uses_refs = []
    block_indent = None

    for lineno, raw_line in enumerate(lines, start=1):
        if block_indent is not None:
            stripped = raw_line.strip()
            current_indent = len(raw_line) - len(raw_line.lstrip(" "))
            if stripped == "" or current_indent > block_indent:
                continue
            block_indent = None

        cleaned = strip_inline_comment(raw_line).rstrip()
        if not cleaned.strip():
            continue

        block_match = block_scalar_pattern.match(cleaned)
        if block_match:
            block_indent = len(block_match.group(1))

        if top_permissions_empty.match(cleaned):
            has_top_permissions_empty = True
        elif top_permissions_any.match(cleaned):
            has_other_top_permissions = True

        if persist_false_pattern.match(cleaned):
            persist_false_count += 1

        uses_match = uses_pattern.match(cleaned)
        if uses_match:
            ref = uses_match.group(1).strip()
            if (ref.startswith('"') and ref.endswith('"')) or (
                ref.startswith("'") and ref.endswith("'")
            ):
                ref = ref[1:-1].strip()
            uses_refs.append((lineno, ref))
            if ref.startswith("actions/checkout@"):
                checkout_count += 1

    if not has_top_permissions_empty or has_other_top_permissions:
        failures.append(f"{rel}: 必须在工作流顶层声明 permissions: {{}}")
    if persist_false_count == 0 or persist_false_count < checkout_count:
        failures.append(f"{rel}: 必须显式配置 persist-credentials: false")
    if not uses_refs:
        failures.append(f"{rel}: 未检测到任何 uses: 引用")
    for lineno, ref in uses_refs:
        if not sha_uses_pattern.fullmatch(ref):
            failures.append(
                f"{rel}:{lineno}: uses 引用 '{ref}' 必须固定为 40 位完整小写 commit SHA（@[0-9a-f]{{40}}）"
            )

if failures:
    for item in failures:
        print(f"error: {item}", file=sys.stderr)
    sys.exit(1)

print(f"ok ({len(workflow_files)} workflow(s) checked)")
PY

step 'SwiftPM 清单'
swift package --package-path "$repository_root" dump-package >/dev/null
echo 'ok'

base_url=$(read_constant officialArtifactBaseURL)

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
