# インストーラ作成Makefile
# 公証に必要なので先に "Developer ID Application" のCertificateを生成してインストールしておくこと。
# pbxprojファイルからバージョン (MARKETING_VERSION) を取得するのにjqを使っているのでインストールしておくこと。
# 公証のためのApp Passwordは先にKeychainに入れておくこと. 次のコマンドで実行できる
# xcrun notarytool store-credentials $(CREDENTIALS_PROFILE) --apple-id $(APPLE_ID) --team-id $(APPLE_TEAM_ID)
# See https://developer.apple.com/documentation/technotes/tn3147-migrating-to-the-latest-notarization-tool#Save-credentials-in-the-keychain

# 設定項目
#APPLE_ID := hogerappa@gmail.com
APPLE_TEAM_ID := W3A6B7FDC7
CREDENTIALS_PROFILE := macSKK
VERSION := $(shell xcodebuild -project macSKK.xcodeproj -target macSKK -showBuildSettings -json | jq -r '.[0].buildSettings.MARKETING_VERSION')

WORKDIR := script/work
SCRIPTSDIR := script/scripts
XCARCHIVE := $(WORKDIR)/macSKK-$(VERSION).xcarchive
APP := "$(WORKDIR)/export/macSKK.app"
DSYMS := $(XCARCHIVE)/dSYMs
DICT := $(WORKDIR)/SKK-JISYO.L
APP_PKG := $(WORKDIR)/app.pkg
DICT_PKG := $(WORKDIR)/dict.pkg
INSTALLER_PKG := $(WORKDIR)/pkg/macSKK-$(VERSION).pkg
UNSIGNED_PKG := $(WORKDIR)/macSKK-unsigned-$(VERSION).pkg
# 最終成果物
TARGET_DMG := $(WORKDIR)/macSKK-$(VERSION).dmg
# ビルド時に生成されたdSYM (XPCのdSYMを含む)
TARGET_DSYM_ARCHIVE := $(WORKDIR)/macSKK-$(VERSION)-dSYMs.zip
APP_PKG_ID := net.mtgto.inputmethod.macSKK.app
DICT_PKG_ID := net.mtgto.inputmethod.macSKK.dict
PRODUCT_SIGN_ID := "Developer ID Installer"

.PHONY: all $(DICT)

$(XCARCHIVE):
	xcodebuild -project macSKK.xcodeproj -scheme macSKK -configuration Release CODE_SIGN_IDENTITY="Developer ID Application" DEVELOPMENT_TEAM=$(APPLE_TEAM_ID) OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime" CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO CODE_SIGN_STYLE=Manual -archivePath $(XCARCHIVE) archive

$(APP): $(XCARCHIVE)
	xcodebuild -exportArchive -archivePath $(XCARCHIVE) -exportOptionsPlist script/export-options.plist -exportPath $(WORKDIR)/export

all: $(XCARCHIVE)

$(DICT):
	$(eval DICT_DIGEST_LATEST := $(shell curl --silent https://skk-dev.github.io/dict/SKK-JISYO.L.gz.md5 | cut -w -f 1))
	$(eval DICT_DIGEST := $(shell if [ -f $(WORKDIR)/SKK-JISYO.L.gz ]; then md5 -q $(WORKDIR)/SKK-JISYO.L.gz; else echo NA; fi))
	if [ $(DICT_DIGEST) != $(DICT_DIGEST_LATEST) ]; then \
		curl https://skk-dev.github.io/dict/SKK-JISYO.L.gz -o $(WORKDIR)/SKK-JISYO.L.gz; \
		gzip --decompress --keep --force $(WORKDIR)/SKK-JISYO.L.gz; \
	fi

$(DICT_PKG): $(DICT)
	mkdir -p $(WORKDIR)/dict/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Dictionaries
	cp $< $(WORKDIR)/dict/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Dictionaries
	pkgbuild --root $(WORKDIR)/dict --component-plist script/dict.plist --identifier $(DICT_PKG_ID) --version $(VERSION) --install-location / $(DICT_PKG)

$(APP_PKG): $(APP)
	mkdir -p $(WORKDIR)/app/Library/Input\ Methods
	cp -r $< $(WORKDIR)/app/Library/Input\ Methods
	pkgbuild --root $(WORKDIR)/app --component-plist script/app.plist --identifier $(APP_PKG_ID) --version $(VERSION) --install-location / --scripts $(SCRIPTSDIR) $(APP_PKG)

$(INSTALLER_PKG): $(APP_PKG) $(DICT_PKG)
	mkdir -p $(WORKDIR)/pkg
	productbuild --distribution script/distribution.xml --resources script --package-path $(WORKDIR) $(UNSIGNED_PKG)
	productsign --sign $(PRODUCT_SIGN_ID) $(UNSIGNED_PKG) $(INSTALLER_PKG)
	# store-credentialsしてある場合はキーチェーンの情報を使うのでAPPLE_IDは不要。
	# 将来、公証をGitHub Actionsなどで実行することになったらApp Passwordを使うようにするかも。
	#xcrun notarytool submit $(INSTALLER_PKG) --team-id $(APPLE_TEAM_ID) --apple-id $(APPLE_ID) --wait
	xcrun notarytool submit $(INSTALLER_PKG) -p $(CREDENTIALS_PROFILE) --wait
	xcrun stapler staple $(INSTALLER_PKG)

$(TARGET_DMG): $(INSTALLER_PKG)
	if [ -f $(TARGET_DMG) ]; then rm $(TARGET_DMG); fi
	cp LICENSE $(WORKDIR)/pkg
	hdiutil create -srcfolder $(WORKDIR)/pkg -volname macSKK -fs HFS+ $(TARGET_DMG)

# zipが-rするときの作業ディレクトリを指定できないので雑な相対指定をしている
$(TARGET_DSYM_ARCHIVE): $(APP)
	rm -f $(TARGET_DSYM_ARCHIVE)
	pushd $(XCARCHIVE)/dSYMs; zip ../../../../$(TARGET_DSYM_ARCHIVE) -r .; popd

release: $(TARGET_DMG) $(TARGET_DSYM_ARCHIVE)

clean:
	rm -rf $(WORKDIR) build
