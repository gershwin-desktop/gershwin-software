#import <AppKit/AppKit.h>
#import "Software.h"

int main(int argc, const char *argv[])
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSApplication *app = [NSApplication sharedApplication];
    
    Software *manager = [[Software alloc] init];
    [app setDelegate:manager];
    
    int result = NSApplicationMain(argc, argv);
    
    [manager release];
    [pool release];
    
    return result;
}
