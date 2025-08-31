#import "AppDelegate.h"
#import "HelloWorld.h"
#import <AppKit/AppKit.h>

@implementation AppDelegate {
  NSWindow *_window;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
  [self createAppMenu];
  [self createMainWindow];
}

- (void)createAppMenu
{
  NSMenu *mainMenu = [[NSMenu alloc] init];
  NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
  [mainMenu addItem:appMenuItem];
  [NSApp setMainMenu:mainMenu];

  NSString *appName = [[NSProcessInfo processInfo] processName];
  NSMenu *appMenu = [[NSMenu alloc] initWithTitle:appName];

  NSString *quitTitle = [NSString stringWithFormat:@"Quit %@", appName];
  NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:quitTitle
                                                    action:@selector(terminate:)
                                             keyEquivalent:@"q"];
  [quitItem setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
  [appMenu addItem:quitItem];

  [appMenuItem setSubmenu:appMenu];
}

- (void)createMainWindow
{
  NSRect frame = NSMakeRect(0, 0, 600, 400);
  NSUInteger style =
      NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable;

  _window = [[NSWindow alloc] initWithContentRect:frame
                                        styleMask:style
                                          backing:NSBackingStoreBuffered
                                            defer:NO];
  [_window setTitle:@"Hello, World!"];
  [_window center];

  HelloWorld *view = [[HelloWorld alloc] initWithFrame:frame];
  [_window setContentView:view];
  [_window makeKeyAndOrderFront:nil];
}

@end
