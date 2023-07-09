TARGET = build/Release/macSKK.app

all: $(TARGET)
	xcodebuild -project macSKK.xcodeproj -configuration Release build

pkg:
	echo
