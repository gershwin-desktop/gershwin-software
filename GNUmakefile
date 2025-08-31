include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = Software

$(APP_NAME)_OBJC_FILES = \
	main.m \
	Software.m

$(APP_NAME)_HEADERS = \
	Software.h

$(APP_NAME)_RESOURCE_FILES = \
	Software.png

$(APP_NAME)_OBJCFLAGS += -Wall -Wextra -O2
$(APP_NAME)_LDFLAGS += -L/usr/local/lib
$(APP_NAME)_CPPFLAGS += -I/usr/local/include

include $(GNUSTEP_MAKEFILES)/application.make

after-all::
	@echo '{' > $(APP_NAME).app/Resources/Info-gnustep.plist
	@echo '    ApplicationName = "$(APP_NAME)";' >> $(APP_NAME).app/Resources/Info-gnustep.plist
	@echo '    ApplicationDescription = "Gershwin Software Manager";' >> $(APP_NAME).app/Resources/Info-gnustep.plist
	@echo '    ApplicationRelease = "1.0.0";' >> $(APP_NAME).app/Resources/Info-gnustep.plist
	@echo '    NSExecutable = "$(APP_NAME)";' >> $(APP_NAME).app/Resources/Info-gnustep.plist
	@echo '    CFBundleIconFile = "Software.png";' >> $(APP_NAME).app/Resources/Info-gnustep.plist
	@echo '    NSPrincipalClass = "NSApplication";' >> $(APP_NAME).app/Resources/Info-gnustep.plist
	@echo '    NSHighResolutionCapable = "YES";' >> $(APP_NAME).app/Resources/Info-gnustep.plist
	@echo '    CFBundleVersion = "1.0.0";' >> $(APP_NAME).app/Resources/Info-gnustep.plist
	@echo '    CFBundleShortVersionString = "1.0.0";' >> $(APP_NAME).app/Resources/Info-gnustep.plist
	@echo '    CFBundleIdentifier = "org.gershwin.software-manager";' >> $(APP_NAME).app/Resources/Info-gnustep.plist
	@echo '}' >> $(APP_NAME).app/Resources/Info-gnustep.plist
	@if [ -f Software.png ]; then \
		cp Software.png $(APP_NAME).app/Resources/; \
	else \
		touch $(APP_NAME).app/Resources/Software.png; \
	fi
	@chmod +x $(APP_NAME).app/$(APP_NAME)

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
