#!/usr/bin/env bash

set -e
# ビルド
xcodebuild -workspace macSKK.xcodeproj/project.xcworkspace -scheme macSKK -configuration Debug DEVELOPMENT_TEAM= clean archive -archivePath build/archive.xcarchive

# 上書き
if [[ -d ~/Library/Input\ Methods/macSKK.app ]]; then
    echo "Update ~/Library/Input Methods/macSKK.app"

    rm -rf ~/Library/Input\ Methods/macSKK.app
    cp -r build/archive.xcarchive/Products/Library/Input\ Methods/macSKK.app ~/Library/Input\ Methods/
elif [[ -d /Library/Input\ Methods/macSKK.app ]]; then
    echo "Update /Library/Input Methods/macSKK.app"

    sudo rm -rf /Library/Input\ Methods/macSKK.app
    sudo cp -r build/archive.xcarchive/Products/Library/Input\ Methods/macSKK.app /Library/Input\ Methods/
fi

# 再起動
pkill "macSKK"
