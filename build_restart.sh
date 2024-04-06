#!/usr/bin/env bash

set -e
# ビルド
xcodebuild -workspace macSKK.xcodeproj/project.xcworkspace -scheme macSKK clean archive -archivePath build/archive.xcarchive
# 上書き
sudo rm -rf /Library/Input\ Methods/macSKK.app
sudo cp -r build/archive.xcarchive/Products/Library/Input\ Methods/macSKK.app ~/Library/Input\ Methods/
# 再起動
pkill "macSKK"
