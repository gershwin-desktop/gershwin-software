#import "HelloWorld.h"

@implementation HelloWorld

- (void)drawRect:(NSRect)dirtyRect
{
  [super drawRect:dirtyRect];

  NSString *message = @"Hello, World!";
  NSDictionary *attrs = @{
    NSFontAttributeName : [NSFont systemFontOfSize:32],
    NSForegroundColorAttributeName : [NSColor blackColor]
  };

  NSSize textSize = [message sizeWithAttributes:attrs];
  NSPoint textOrigin = NSMakePoint(NSMidX(self.bounds) - textSize.width / 2,
                                   NSMidY(self.bounds) - textSize.height / 2);

  [message drawAtPoint:textOrigin withAttributes:attrs];
}

@end
