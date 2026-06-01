#!/bin/bash

# Flutter 国内镜像启动脚本
# 使用方法: ./run.sh 或 bash run.sh

export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

echo "✅ 已启用Flutter国内镜像"
echo "   PUB_HOSTED_URL: $PUB_HOSTED_URL"
echo "   FLUTTER_STORAGE_BASE_URL: $FLUTTER_STORAGE_BASE_URL"
echo ""

# 执行传入的命令（默认为 flutter run --flavor dev）
if [ -z "$1" ]; then
  flutter run --flavor dev
else
  flutter "$@"
fi
