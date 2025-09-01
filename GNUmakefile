include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = Software

$(APP_NAME)_OBJC_FILES = \
	main.m \
	Software.m

$(APP_NAME)_HEADERS = \
	Software.h

$(APP_NAME)_RESOURCE_FILES = \
	SoftwareInfo.plist \
	Software.png

$(APP_NAME)_OBJCFLAGS += -Wall -Wextra -O2
$(APP_NAME)_LDFLAGS += -L/usr/local/lib
$(APP_NAME)_CPPFLAGS += -I/usr/local/include

include $(GNUSTEP_MAKEFILES)/application.make

clean::
	@rm -rf $(APP_NAME).app *.o

install::
	@if [ -d "/Applications" ]; then \
		cp -r $(APP_NAME).app /Applications/; \
		echo "Software.app installed to /Applications/"; \
	else \
		echo "Error: /Applications directory not found"; \
		exit 1; \
	fi

uninstall::
	@if [ -d "/Applications/$(APP_NAME).app" ]; then \
		rm -rf "/Applications/$(APP_NAME).app"; \
		echo "Software.app removed from /Applications/"; \
	fi

.PHONY: install uninstall clean
