# extension-fixer-cross-platform

跨平台「按真实内容修正文件扩展名」工具 —— 适用于 **macOS / Linux / FreeBSD**。

很多文件（尤其从微信、网页、网盘下载的图片）扩展名与真实格式不一致，
导致 Finder / 文件管理器不显示预览。本工具用 `file --mime-type` 读取文件
**真实内容**识别类型，自动把扩展名改成正确的。

## 兼容性

| 系统 | 状态 | 备注 |
|---|---|---|
| macOS | ✅ 已验证（file 5.41 实测通过） | 系统自带 bash 3.2 即可运行，无需额外安装 |
| Linux | ✅ | 依赖 bash + GNU file，主流发行版默认都带 |
| FreeBSD | ✅ | 需自行安装 bash（`pkg install bash`） |

> ⚠️ 提醒：HEIC/AVIF 等较新格式的识别精度取决于系统 `file` 的 magic
> 数据库版本；过旧的版本可能识别成 `application/octet-stream` 而跳过。

## 使用

```bash
./fixext.sh -n <文件或目录>...   # 预览：只打印将如何重命名（默认行为）
./fixext.sh -y <文件或目录>...   # 执行：实际重命名
./fixext.sh -yr <目录>           # 递归处理子目录中的所有文件
```

示例：

```bash
./fixext.sh -n ~/Pictures            # 先预览
./fixext.sh -y ~/Pictures            # 确认无误后执行
./fixext.sh -yr ~/Photos             # 连同子目录一起处理
```

## 行为特性

- **只重命名，绝不修改文件内容**（仅 `mv`，无任何二进制改动）
- 跳过隐藏文件、符号链接、无法识别 / 未映射的类型（如文本文件）
- 目标名已存在时自动追加 `-2`、`-3`… 序号，绝不复盖
- 扩展名大小写不敏感（`PNG` / `png` 均视为正确）
- 支持常见图片（jpg/png/gif/webp/heic/avif/tiff/bmp/ico/svg）、音视频
  （mp3/m4a/flac/ogg/wav/mp4/avi/mov/webm/mkv）、压缩包和文档
  （zip/tar/gz/7z/rar/pdf/epub/docx/xlsx/pptx 等）
- 类型映射表在脚本内 `want_ext()` 函数，自行增删即可扩展

## 许可证

MIT License — Copyright (c) 2026 Se@n908