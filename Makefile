TARGET = build/Release/macSKK.app
WORKDIR = script/work
PKG_ID = macSKK

all:
	xcodebuild -project macSKK.xcodeproj -configuration Release build

pkg: $(TARGET)
	mkdir -p $(WORKDIR)/Library/Input\ Methods
	mv $< $(WORKDIR)/Library/Input\ Methods
	pkgbuild --root $(WORKDIR) --component-plist script/pkg.plist --identifier $(PKG_ID) script/macSKK.pkg
  productbuild --distribution script/distribution.xml --resources script --package-path script/macSKK.pkg macSKK.pkg
