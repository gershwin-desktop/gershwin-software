#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface Software : NSObject <NSTableViewDataSource, NSTableViewDelegate>
{
    NSWindow *mainWindow;
    NSTableView *applicationTableView;
    NSTextView *logTextView;
    NSButton *buildButton;
    NSButton *installButton;
    NSButton *refreshButton;
    NSProgressIndicator *progressIndicator;
    NSTextField *statusLabel;
    
    NSMutableArray *applications;
    NSInteger selectedRow;
    
    NSTask *currentTask;
    NSPipe *outputPipe;
    
    NSString *repoPath;
    BOOL isBuilding;
    BOOL isInstalling;
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification;
- (void)applicationDidFinishLaunching:(NSNotification *)notification;
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender;

- (void)setupUI;
- (void)refreshApplicationList;
- (void)scanForApplications;
- (NSArray *)findApplicationsInDirectory:(NSString *)directory;
- (NSDictionary *)parseApplicationInfo:(NSString *)appPath;

- (void)buildApplication:(id)sender;
- (void)installApplication:(id)sender;
- (void)refreshList:(id)sender;

- (void)runCommand:(NSString *)command 
    withArguments:(NSArray *)arguments 
    inDirectory:(NSString *)directory
    requiresAuth:(BOOL)requiresAuth;

- (void)handleTaskOutput:(NSNotification *)notification;
- (void)handleTaskCompletion:(NSNotification *)notification;

- (void)appendToLog:(NSString *)text;
- (void)appendToLog:(NSString *)text withColor:(NSColor *)color;
- (void)updateStatus:(NSString *)status;
- (void)setUIEnabled:(BOOL)enabled;

- (void)tableViewSelectionDidChange:(NSNotification *)notification;
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView;
- (id)tableView:(NSTableView *)tableView 
    objectValueForTableColumn:(NSTableColumn *)tableColumn 
    row:(NSInteger)row;

- (NSString *)promptForPassword;

@end
