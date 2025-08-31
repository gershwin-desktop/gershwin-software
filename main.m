#import "AppDelegate.h"
#import <AppKit/AppKit.h>

int main(int argc, const char *argv[])
{
  @autoreleasepool {
    [NSApplication sharedApplication];

    AppDelegate *delegate = [[AppDelegate alloc] init];
    [NSApp setDelegate:delegate];

    [NSApp run];
  }
  return 0;
}
