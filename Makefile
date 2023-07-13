# インストーラ作成Makefile
# 公証に必要なので先に "Developer ID Application" のCertificateを生成してインストールしておくこと。

# TODO: dmgのファイル名やpkg自体にバージョン番号をつけたほうが管理しやすそう

# 設定項目
APPLE_ID := hogerappa@gmail.com
APPLE_TEAM_ID := W3A6B7FDC7
VERSION := 0.1.0

WORKDIR := script/work
APP := build/Release/macSKK.app
DICT := $(WORKDIR)/SKK-JISYO.L
APP_PKG := $(WORKDIR)/app.pkg
DICT_PKG := $(WORKDIR)/dict.pkg
INSTALLER_PKG := $(WORKDIR)/pkg/macSKK.pkg
UNSIGNED_PKG := $(WORKDIR)/macSKK-unsigned.pkg
TARGET_DMG := $(WORKDIR)/macSKK.dmg
APP_PKG_ID := net.mtgto.inputmethod.macSKK.app
DICT_PKG_ID := net.mtgto.inputmethod.macSKK.dict
PRODUCT_SIGN_ID := "Developer ID Installer"

all:
	xcodebuild -project macSKK.xcodeproj -configuration Release CODE_SIGN_IDENTITY="Developer ID Application" DEVELOPMENT_TEAM=$(APPLE_TEAM_ID) OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime" CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO CODE_SIGN_STYLE=Manual build

# TODO: https://skk-dev.github.io/dict/SKK-JISYO.L.gz.md5 を保持しておいて更新されたときだけダウンロードするようにする
$(DICT):
	curl https://skk-dev.github.io/dict/SKK-JISYO.L.gz -o $(WORKDIR)/SKK-JISYO.L.gz
	gzip --decompress $(WORKDIR)/SKK-JISYO.L.gz

$(DICT_PKG): $(DICT)
	mkdir -p $(WORKDIR)/dict/Library/Containers/net.mtgto.inputmethod.macSKK/Data
	cp $< $(WORKDIR)/dict/Library/Containers/net.mtgto.inputmethod.macSKK/Data
	pkgbuild --root $(WORKDIR)/dict --component-plist script/dict.plist --identifier $(DICT_PKG_ID) --version $(VERSION) --install-location / $(DICT_PKG)

$(APP_PKG): $(APP)
	mkdir -p $(WORKDIR)/app/Library/Input\ Methods
	cp -r $< $(WORKDIR)/app/Library/Input\ Methods
	pkgbuild --root $(WORKDIR)/app --component-plist script/app.plist --identifier $(APP_PKG_ID) --version $(VERSION) --install-location / $(APP_PKG)

$(INSTALLER_PKG): $(APP_PKG) $(DICT_PKG)
	mkdir -p $(WORKDIR)/pkg
	productbuild --distribution script/distribution.xml --resources script --package-path $(WORKDIR) $(UNSIGNED_PKG)
	productsign --sign $(PRODUCT_SIGN_ID) $(UNSIGNED_PKG) $(INSTALLER_PKG)

$(TARGET_DMG): $(INSTALLER_PKG)
	hdiutil create -srcfolder $(WORKDIR)/pkg -volname macSKK -fs HFS+ $(TARGET_DMG)
	xcrun notarytool submit --wait $(TARGET_DMG) --team-id $(APPLE_TEAM_ID) --apple-id $(APPLE_ID)
	xcrun stapler staple $(TARGET_DMG)

release: $(TARGET_DMG)

clean:
	rm -r $(WORKDIR) build
