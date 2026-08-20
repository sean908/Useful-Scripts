#!/usr/bin/env bash
#
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Se@n908
#
# fixext.sh —— 按文件「真实内容」批量修正扩展名
#
# 用法:
#   fixext.sh [选项] 文件或目录...
#
# 选项:
#   -n, --dry-run   只预览将如何重命名，不实际改动（默认行为）
#   -y, --apply     实际执行重命名
#   -r, --recursive 递归处理子目录
#   -h, --help      显示帮助
#
# 原理: 用 file --mime-type 读取文件内容识别真实类型(MIME)，
#       再对照下方 want_ext() 的映射表得出正确扩展名，只有不匹配时才重命名。
#       只处理常规文件；隐藏文件、符号链接、无法识别/未映射的类型都会跳过。
#
# 示例:
#   fixext.sh -n ~/Pictures        # 预览
#   fixext.sh -y ~/Pictures        # 确认无误后执行
#   fixext.sh -yr ~/Pictures       # 连同子目录一起处理
#
set -uo pipefail

APPLY=0
RECURSIVE=0
changed=0
same=0
skipped=0

usage() {
  sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

# MIME 类型 -> 期望扩展名（需要加类型时在这里加一行即可）
want_ext() {
  case "$1" in
    # 图片
    image/jpeg|image/pjpeg)                  echo jpg ;;
    image/png|image/x-png|image/apng)        echo png ;;
    image/gif)                               echo gif ;;
    image/webp)                              echo webp ;;
    image/tiff)                              echo tif ;;
    image/heic)                              echo heic ;;
    image/heif)                              echo heif ;;
    image/avif|image/avif-sequence)          echo avif ;;
    image/bmp|image/x-bmp|image/x-windows-bmp) echo bmp ;;
    image/x-icon|image/vnd.microsoft.icon)   echo ico ;;
    image/svg+xml)                           echo svg ;;
    # 音视频
    audio/mpeg)                              echo mp3 ;;
    audio/mp4|audio/x-m4a)                   echo m4a ;;
    audio/flac|audio/x-flac)                 echo flac ;;
    audio/ogg|application/ogg)               echo ogg ;;
    audio/wav|audio/x-wav)                   echo wav ;;
    audio/x-m4a)                             echo m4a ;;
    video/mp4)                               echo mp4 ;;
    video/x-msvideo)                         echo avi ;;
    video/quicktime)                         echo mov ;;
    video/webm)                              echo webm ;;
    video/x-matroska)                        echo mkv ;;
    # 压缩包/文档
    application/pdf)                         echo pdf ;;
    application/zip)                         echo zip ;;
    application/x-tar)                       echo tar ;;
    application/gzip|application/x-gzip)     echo gz ;;
    application/x-bzip2)                     echo bz2 ;;
    application/x-7z-compressed)             echo 7z ;;
    application/x-rar-compressed)            echo rar ;;
    application/epub+zip)                    echo epub ;;
    application/msword)                      echo doc ;;
    application/vnd.openxmlformats-officedocument.wordprocessingml.document) echo docx ;;
    application/vnd.ms-excel)                echo xls ;;
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet)       echo xlsx ;;
    application/vnd.ms-powerpoint)           echo ppt ;;
    application/vnd.openxmlformats-officedocument.presentationml.presentation) echo pptx ;;
    # 文本（谨慎：不想误改文本文件可删掉这几行）
    text/html)                               echo html ;;
    text/csv)                                echo csv ;;
    application/json)                        echo json ;;
    *) echo "" ;;
  esac
}

lower() { tr '[:upper:]' '[:lower:]'; }

# 计算目标新路径；打印空串表示「无需改名」
newname_for() {
  local f="$1" want="$2"
  local dir base name cur new i
  if [[ "$f" == */* ]]; then dir=${f%/*}; else dir="."; fi
  base=${f##*/}
  case "$base" in
    *.*) name=${base%.*} ; cur=${base##*.} ;;
    *)   name=$base      ; cur="" ;;
  esac
  # 已存在且匹配正确扩展名 -> 无需修改（大小写不敏感）
  if [[ -n "$cur" && "$(printf '%s' "$cur" | lower)" == "$want" ]]; then
    echo ""; return
  fi
  # 文件名本身以 . 开头（如 .gitignore）→ 保持不动
  [[ -z "$name" || "$name" == .* ]] && { echo ""; return; }

  new="$dir/$name.$want"
  # 目标已存在且不是自己 → 追加序号，避免覆盖
  if [[ -e "$new" && "$new" != "$f" ]]; then
    i=2
    while [[ -e "$dir/$name-$i.$want" ]]; do i=$((i+1)); done
    new="$dir/$name-$i.$want"
  fi
  printf '%s' "$new"
}

fix_one() {
  local f="$1" mime want new
  # 只处理常规文件（跳过目录、符号链接等）
  if [[ ! -f "$f" || -L "$f" ]]; then
    printf '跳过(非普通文件): %s\n' "$f"; skipped=$((skipped+1)); return
  fi
  [[ "$(basename "$f")" == .* ]] && { skipped=$((skipped+1)); return; }

  mime=$(file --mime-type -b "$f" 2>/dev/null)
  if [[ -z "$mime" ]]; then
    mime=$(file -bI "$f" 2>/dev/null | sed 's/;.*//')
  fi
  [[ -z "$mime" ]] && { printf '跳过(无法识别): %s\n' "$f"; skipped=$((skipped+1)); return; }

  want=$(want_ext "$mime")
  [[ -z "$want" ]] && { printf '跳过(未映射 %s): %s\n' "$mime" "$f"; skipped=$((skipped+1)); return; }

  new=$(newname_for "$f" "$want")
  [[ -z "$new" ]] && { printf '无需修改: %s\n' "$f"; same=$((same+1)); return; }

  if [[ "$APPLY" == 1 ]]; then
    if mv -- "$f" "$new" 2>/dev/null || mv "$f" "$new"; then
      printf '√ 已重命名: %s -> %s\n' "$f" "${new#./}"
      changed=$((changed+1))
    else
      printf 'x 重命名失败: %s\n' "$f"; skipped=$((skipped+1))
    fi
  else
    printf '√ 将重命名: %s -> %s\n' "$f" "${new#./}"
    changed=$((changed+1))
  fi
}

process_dir() {
  local d="$1" f
  if [[ "$RECURSIVE" == 1 ]]; then
    while IFS= read -r -d '' f; do fix_one "$f"; done < <(find "$d" -type f -print0)
  else
    for f in "$d"/* "$d"/.[!.]*; do
      [[ -e "$f" ]] && fix_one "$f"
    done
  fi
}

while getopts "nyrh" opt; do
  case "$opt" in
    n) APPLY=0 ;;
    y) APPLY=1 ;;
    r) RECURSIVE=1 ;;
    h) usage 0 ;;
    *) usage 1 ;;
  esac
done
shift $((OPTIND-1))
[[ $# -eq 0 ]] && usage 1

for p in "$@"; do
  if [[ -d "$p" ]]; then process_dir "$p"; else fix_one "$p"; fi
done

echo "----------------------------------------"
echo "结果: $changed 个待改名, $same 个已正确, $skipped 个跳过"
[[ "$APPLY" == 1 ]] || echo "（以上为预览，确认无误后加 -y 真正执行）"