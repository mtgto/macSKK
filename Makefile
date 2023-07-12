WORKDIR := script/work
APP := build/Release/macSKK.app
DICT := $(WORKDIR)/SKK-JISYO.L
APP_PKG := $(WORKDIR)/app.pkg
DICT_PKG := $(WORKDIR)/dict.pkg
INSTALLER_PKG := $(WORKDIR)/macSKK.pkg
APP_PKG_ID := net.mtgto.inputmethod.macSKK.app-pkg
DICT_PKG_ID := net.mtgto.inputmethod.macSKK.dict-pkg

all:
	xcodebuild -project macSKK.xcodeproj -configuration Release build

# TODO: https://skk-dev.github.io/dict/SKK-JISYO.L.gz.md5 を保持しておいて更新されたときだけダウンロードするようにする
$(DICT):
	curl https://skk-dev.github.io/dict/SKK-JISYO.L.gz -o $(WORKDIR)/SKK-JISYO.L.gz
	gzip --decompress $(WORKDIR)/SKK-JISYO.L.gz

$(DICT_PKG): $(DICT)
	mkdir -p $(WORKDIR)/dict/Library/Containers/net.mtgto.inputmethod.macSKK/Data
	mv $< $(WORKDIR)/dict/Library/Containers/net.mtgto.inputmethod.macSKK/Data
	pkgbuild --root $(WORKDIR)/dict --component-plist script/dict.plist --identifier $(DICT_PKG_ID) $(DICT_PKG)

$(APP_PKG): $(APP)
	mkdir -p $(WORKDIR)/app/Library/Input\ Methods
	cp -r $< $(WORKDIR)/app/Library/Input\ Methods
	pkgbuild --root $(WORKDIR)/app --component-plist script/app.plist --identifier $(APP_PKG_ID) $(APP_PKG)

$(INSTALLER_PKG): $(APP_PKG) $(DICT_PKG)
	productbuild --distribution script/distribution.xml --resources script --package-path $(WORKDIR) $(INSTALLER_PKG)

clean:
	rm -r $(WORKDIR)
