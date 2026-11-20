#!/bin/bash
# macOS 上一键构建未签名 IPA（签名交给你自己的侧载工具）
set -e
cd "$(dirname "$0")"

command -v xcodegen >/dev/null 2>&1 || { echo "先安装: brew install xcodegen"; exit 1; }

xcodegen generate

xcodebuild -project Netmon.xcodeproj \
  -scheme Netmon \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

APP="build/Build/Products/Release-iphoneos/Netmon.app"
rm -rf out && mkdir -p out/Payload
cp -R "$APP" out/Payload/
(cd out && zip -qry Netmon-unsigned.ipa Payload)

echo "完成: $(pwd)/out/Netmon-unsigned.ipa"
