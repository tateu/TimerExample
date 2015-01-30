ARCHS = armv7 arm64
TARGET = iphone:clang::latest

PACKAGE_VERSION = $(THEOS_PACKAGE_BASE_VERSION)

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TimerExample
TimerExample_FILES = Tweak.xm
TimerExample_FRAMEWORKS = UIKit

CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
