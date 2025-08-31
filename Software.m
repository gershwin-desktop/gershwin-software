#import "Software.h"
#import <sys/types.h>
#import <sys/stat.h>
#import <unistd.h>

@implementation Software

- (id)init
{
    self = [super init];
    if (self) {
        applications = [[NSMutableArray alloc] init];
        selectedRow = -1;
        isBuilding = NO;
        isInstalling = NO;
        
        // Set the repo path - adjust this to your actual repo location
        NSString *homeDir = NSHomeDirectory();
        repoPath = [[homeDir stringByAppendingPathComponent:@"gershwin-universe-wrappers"] retain];
        
        // Check if repo exists, if not try /tmp or current directory
        if (![[NSFileManager defaultManager] fileExistsAtPath:repoPath]) {
            NSString *tmpPath = @"/tmp/gershwin-universe-wrappers";
            if ([[NSFileManager defaultManager] fileExistsAtPath:tmpPath]) {
                [repoPath release];
                repoPath = [tmpPath retain];
            } else {
                // Try current directory
                NSString *currentPath = [[NSFileManager defaultManager] currentDirectoryPath];
                NSString *currentRepoPath = [currentPath stringByAppendingPathComponent:@"gershwin-universe-wrappers"];
                if ([[NSFileManager defaultManager] fileExistsAtPath:currentRepoPath]) {
                    [repoPath release];
                    repoPath = [currentRepoPath retain];
                }
            }
        }
    }
    return self;
}

- (void)dealloc
{
    [applications release];
    [repoPath release];
    [currentTask release];
    [outputPipe release];
    [super dealloc];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
    [self setupUI];
    
    NSString *iconPath = [[NSBundle mainBundle] pathForResource:@"Software" ofType:@"png"];
    if (iconPath && [[NSFileManager defaultManager] fileExistsAtPath:iconPath]) {
        NSImage *icon = [[NSImage alloc] initWithContentsOfFile:iconPath];
        if (icon) {
            [NSApp setApplicationIconImage:icon];
            [icon release];
        }
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    [mainWindow makeKeyAndOrderFront:nil];
    [self refreshApplicationList];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

- (void)setupUI
{
    // Create main window
    mainWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(100, 100, 800, 600)
                                              styleMask:(NSWindowStyleMaskTitled | 
                                                        NSWindowStyleMaskClosable | 
                                                        NSWindowStyleMaskMiniaturizable | 
                                                        NSWindowStyleMaskResizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    [mainWindow setTitle:@"Gershwin Software Manager"];
    [mainWindow setMinSize:NSMakeSize(600, 400)];
    
    NSView *contentView = [mainWindow contentView];
    
    // Create split view
    NSSplitView *splitView = [[NSSplitView alloc] initWithFrame:[contentView bounds]];
    [splitView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [splitView setDividerStyle:NSSplitViewDividerStyleThin];
    [splitView setVertical:NO];
    
    // Upper view for application list
    NSView *upperView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 800, 300)];
    
    // Create scroll view for table
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(10, 50, 780, 240)];
    [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setBorderType:NSBezelBorder];
    
    // Create table view
    applicationTableView = [[NSTableView alloc] initWithFrame:[[scrollView contentView] bounds]];
    [applicationTableView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [applicationTableView setUsesAlternatingRowBackgroundColors:YES];
    [applicationTableView setRowHeight:24];
    
    // Add columns
    NSTableColumn *nameColumn = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    [[nameColumn headerCell] setStringValue:@"Application"];
    [nameColumn setWidth:200];
    [applicationTableView addTableColumn:nameColumn];
    [nameColumn release];
    
    NSTableColumn *versionColumn = [[NSTableColumn alloc] initWithIdentifier:@"version"];
    [[versionColumn headerCell] setStringValue:@"Version"];
    [versionColumn setWidth:100];
    [applicationTableView addTableColumn:versionColumn];
    [versionColumn release];
    
    NSTableColumn *statusColumn = [[NSTableColumn alloc] initWithIdentifier:@"status"];
    [[statusColumn headerCell] setStringValue:@"Status"];
    [statusColumn setWidth:150];
    [applicationTableView addTableColumn:statusColumn];
    [statusColumn release];
    
    NSTableColumn *pathColumn = [[NSTableColumn alloc] initWithIdentifier:@"path"];
    [[pathColumn headerCell] setStringValue:@"Path"];
    [pathColumn setWidth:300];
    [applicationTableView addTableColumn:pathColumn];
    [pathColumn release];
    
    [applicationTableView setDataSource:self];
    [applicationTableView setDelegate:self];
    
    [scrollView setDocumentView:applicationTableView];
    [upperView addSubview:scrollView];
    [scrollView release];
    
    // Create buttons
    buildButton = [[NSButton alloc] initWithFrame:NSMakeRect(10, 10, 100, 30)];
    [buildButton setTitle:@"Build"];
    [buildButton setButtonType:NSMomentaryPushInButton];
    [buildButton setBezelStyle:NSRoundedBezelStyle];
    [buildButton setTarget:self];
    [buildButton setAction:@selector(buildApplication:)];
    [buildButton setEnabled:NO];
    [upperView addSubview:buildButton];
    
    installButton = [[NSButton alloc] initWithFrame:NSMakeRect(120, 10, 100, 30)];
    [installButton setTitle:@"Install"];
    [installButton setButtonType:NSMomentaryPushInButton];
    [installButton setBezelStyle:NSRoundedBezelStyle];
    [installButton setTarget:self];
    [installButton setAction:@selector(installApplication:)];
    [installButton setEnabled:NO];
    [upperView addSubview:installButton];
    
    refreshButton = [[NSButton alloc] initWithFrame:NSMakeRect(230, 10, 100, 30)];
    [refreshButton setTitle:@"Refresh"];
    [refreshButton setButtonType:NSMomentaryPushInButton];
    [refreshButton setBezelStyle:NSRoundedBezelStyle];
    [refreshButton setTarget:self];
    [refreshButton setAction:@selector(refreshList:)];
    [upperView addSubview:refreshButton];
    
    // Progress indicator
    progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(340, 15, 20, 20)];
    [progressIndicator setStyle:NSProgressIndicatorSpinningStyle];
    [progressIndicator setDisplayedWhenStopped:NO];
    [upperView addSubview:progressIndicator];
    
    // Status label
    statusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(370, 10, 410, 30)];
    [statusLabel setEditable:NO];
    [statusLabel setBordered:NO];
    [statusLabel setBackgroundColor:[NSColor clearColor]];
    [statusLabel setStringValue:@"Ready"];
    [upperView addSubview:statusLabel];
    
    // Lower view for log output
    NSView *lowerView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 800, 280)];
    
    NSTextField *logLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 250, 100, 20)];
    [logLabel setEditable:NO];
    [logLabel setBordered:NO];
    [logLabel setBackgroundColor:[NSColor clearColor]];
    [logLabel setStringValue:@"Build Output:"];
    [lowerView addSubview:logLabel];
    [logLabel release];
    
    NSScrollView *logScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(10, 10, 780, 230)];
    [logScrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [logScrollView setHasVerticalScroller:YES];
    [logScrollView setBorderType:NSBezelBorder];
    
    logTextView = [[NSTextView alloc] initWithFrame:[[logScrollView contentView] bounds]];
    [logTextView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [logTextView setEditable:NO];
    [logTextView setRichText:YES];
    [logTextView setFont:[NSFont fontWithName:@"Menlo" size:11]];
    [logTextView setBackgroundColor:[NSColor blackColor]];
    [logTextView setTextColor:[NSColor greenColor]];
    
    [logScrollView setDocumentView:logTextView];
    [lowerView addSubview:logScrollView];
    [logScrollView release];
    
    [splitView addSubview:upperView];
    [splitView addSubview:lowerView];
    [upperView release];
    [lowerView release];
    
    [contentView addSubview:splitView];
    [splitView release];
}

- (void)refreshApplicationList
{
    [self updateStatus:@"Scanning for applications..."];
    [progressIndicator startAnimation:nil];
    [applications removeAllObjects];
    
    [self scanForApplications];
    
    [applicationTableView reloadData];
    [progressIndicator stopAnimation:nil];
    [self updateStatus:[NSString stringWithFormat:@"Found %lu applications", [applications count]]];
}

- (void)scanForApplications
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:repoPath]) {
        [self appendToLog:[NSString stringWithFormat:@"Repository not found at: %@\n", repoPath] 
                withColor:[NSColor redColor]];
        [self updateStatus:@"Repository not found"];
        return;
    }
    
    NSArray *foundApps = [self findApplicationsInDirectory:repoPath];
    [applications addObjectsFromArray:foundApps];
}

- (NSArray *)findApplicationsInDirectory:(NSString *)directory
{
    NSMutableArray *foundApps = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:directory];
    NSString *path;
    
    while ((path = [enumerator nextObject])) {
        NSString *fullPath = [directory stringByAppendingPathComponent:path];
        BOOL isDir;
        
        if ([fm fileExistsAtPath:fullPath isDirectory:&isDir] && isDir) {
            // Check if this directory contains a GNUmakefile
            NSString *makefilePath = [fullPath stringByAppendingPathComponent:@"GNUmakefile"];
            NSString *preamblePath = [fullPath stringByAppendingPathComponent:@"GNUmakefile.preamble"];
            
            if ([fm fileExistsAtPath:makefilePath] && [fm fileExistsAtPath:preamblePath]) {
                NSDictionary *appInfo = [self parseApplicationInfo:fullPath];
                if (appInfo) {
                    [foundApps addObject:appInfo];
                }
                [enumerator skipDescendents];
            }
        }
    }
    
    return foundApps;
}

- (NSDictionary *)parseApplicationInfo:(NSString *)appPath
{
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    NSString *preamblePath = [appPath stringByAppendingPathComponent:@"GNUmakefile.preamble"];
    
    NSError *error;
    NSString *content = [NSString stringWithContentsOfFile:preamblePath 
                                                  encoding:NSUTF8StringEncoding 
                                                     error:&error];
    if (!content) {
        return nil;
    }
    
    // Parse the preamble file
    NSArray *lines = [content componentsSeparatedByString:@"\n"];
    for (NSString *line in lines) {
        NSArray *parts = [line componentsSeparatedByString:@"="];
        if ([parts count] == 2) {
            NSString *key = [[parts objectAtIndex:0] stringByTrimmingCharactersInSet:
                           [NSCharacterSet whitespaceCharacterSet]];
            NSString *value = [[parts objectAtIndex:1] stringByTrimmingCharactersInSet:
                             [NSCharacterSet whitespaceCharacterSet]];
            
            if ([key isEqualToString:@"APP_NAME"]) {
                [info setObject:value forKey:@"name"];
            } else if ([key isEqualToString:@"VERSION"]) {
                [info setObject:value forKey:@"version"];
            } else if ([key isEqualToString:@"EXECUTABLE_PATH"]) {
                [info setObject:value forKey:@"executable"];
            }
        }
    }
    
    [info setObject:appPath forKey:@"path"];
    
    // Check if already installed
    NSString *appName = [info objectForKey:@"name"];
    if (appName) {
        NSString *installedPath = [NSString stringWithFormat:@"/Applications/%@.app", appName];
        if ([[NSFileManager defaultManager] fileExistsAtPath:installedPath]) {
            [info setObject:@"Installed" forKey:@"status"];
        } else {
            // Check if built
            NSString *builtPath = [appPath stringByAppendingPathComponent:
                                 [NSString stringWithFormat:@"%@.app", appName]];
            if ([[NSFileManager defaultManager] fileExistsAtPath:builtPath]) {
                [info setObject:@"Built" forKey:@"status"];
            } else {
                [info setObject:@"Not built" forKey:@"status"];
            }
        }
    }
    
    return info;
}

- (void)buildApplication:(id)sender
{
    if (selectedRow < 0 || selectedRow >= (NSInteger)[applications count]) {
        return;
    }
    
    NSDictionary *app = [applications objectAtIndex:selectedRow];
    NSString *appPath = [app objectForKey:@"path"];
    NSString *appName = [app objectForKey:@"name"];
    
    [self appendToLog:[NSString stringWithFormat:@"\n=== Building %@ ===\n", appName]];
    [self updateStatus:[NSString stringWithFormat:@"Building %@...", appName]];
    
    isBuilding = YES;
    [self setUIEnabled:NO];
    
    [self runCommand:@"/usr/local/bin/gmake" 
       withArguments:@[@"clean", @"all"] 
         inDirectory:appPath
        requiresAuth:NO];
}

- (void)installApplication:(id)sender
{
    if (selectedRow < 0 || selectedRow >= (NSInteger)[applications count]) {
        return;
    }
    
    NSDictionary *app = [applications objectAtIndex:selectedRow];
    NSString *appPath = [app objectForKey:@"path"];
    NSString *appName = [app objectForKey:@"name"];
    NSString *status = [app objectForKey:@"status"];
    
    if (![status isEqualToString:@"Built"] && ![status isEqualToString:@"Installed"]) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Application Not Built"];
        [alert setInformativeText:@"Please build the application before installing."];
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        [alert release];
        return;
    }
    
    [self appendToLog:[NSString stringWithFormat:@"\n=== Installing %@ ===\n", appName]];
    [self updateStatus:[NSString stringWithFormat:@"Installing %@...", appName]];
    
    isInstalling = YES;
    [self setUIEnabled:NO];
    
    // Create authorization script
    NSString *scriptPath = @"/tmp/install_app.sh";
    NSString *scriptContent = [NSString stringWithFormat:
        @"#!/bin/sh\n"
        @"cd '%@'\n"
        @"/usr/local/bin/gmake install\n", appPath];
    
    [scriptContent writeToFile:scriptPath 
                     atomically:YES 
                       encoding:NSUTF8StringEncoding 
                          error:nil];
    
    chmod([scriptPath UTF8String], 0755);
    
    [self runCommand:@"/usr/local/bin/sudo" 
       withArguments:@[@"-S", @"/bin/sh", scriptPath] 
         inDirectory:appPath
        requiresAuth:YES];
}

- (void)refreshList:(id)sender
{
    [self refreshApplicationList];
}

- (void)runCommand:(NSString *)command 
     withArguments:(NSArray *)arguments 
       inDirectory:(NSString *)directory
      requiresAuth:(BOOL)requiresAuth
{
    if (currentTask) {
        [currentTask release];
        currentTask = nil;
    }
    
    currentTask = [[NSTask alloc] init];
    [currentTask setLaunchPath:command];
    [currentTask setArguments:arguments];
    [currentTask setCurrentDirectoryPath:directory];
    
    // Set up pipes for output
    outputPipe = [[NSPipe alloc] init];
    [currentTask setStandardOutput:outputPipe];
    [currentTask setStandardError:outputPipe];
    
    if (requiresAuth) {
        // For sudo, we need to handle password input
        NSPipe *inputPipe = [NSPipe pipe];
        [currentTask setStandardInput:inputPipe];
        
        // Prompt for password
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Administrator Password Required"];
        [alert setInformativeText:@"Please enter your password to install the application:"];
        
        NSSecureTextField *passwordField = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
        
        // Create a view to hold the password field since setAccessoryView might not be available
        NSView *accessoryView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
        [accessoryView addSubview:passwordField];
        
        // Try to set accessory view if method is available
        if ([alert respondsToSelector:@selector(setAccessoryView:)]) {
            [alert setAccessoryView:accessoryView];
        }
        
        [alert addButtonWithTitle:@"OK"];
        [alert addButtonWithTitle:@"Cancel"];
        
        // If accessory view isn't supported, we'll need to get password differently
        NSInteger result;
        if (![alert respondsToSelector:@selector(setAccessoryView:)]) {
            // Fall back to a simple password prompt
            [passwordField release];
            [accessoryView release];
            [alert release];
            
            // Use a simple input dialog instead
            NSString *password = [self promptForPassword];
            if (password) {
                // Write password to sudo
                NSFileHandle *inputHandle = [inputPipe fileHandleForWriting];
                NSString *passwordWithNewline = [password stringByAppendingString:@"\n"];
                [inputHandle writeData:[passwordWithNewline dataUsingEncoding:NSUTF8StringEncoding]];
                [inputHandle closeFile];
            } else {
                [self updateStatus:@"Installation cancelled"];
                [self setUIEnabled:YES];
                isInstalling = NO;
                [outputPipe release];
                outputPipe = nil;
                [currentTask release];
                currentTask = nil;
                return;
            }
        } else {
            result = [alert runModal];
            
            if (result == NSAlertFirstButtonReturn) {
                NSString *password = [passwordField stringValue];
                
                // Write password to sudo
                NSFileHandle *inputHandle = [inputPipe fileHandleForWriting];
                NSString *passwordWithNewline = [password stringByAppendingString:@"\n"];
                [inputHandle writeData:[passwordWithNewline dataUsingEncoding:NSUTF8StringEncoding]];
                [inputHandle closeFile];
            } else {
                [self updateStatus:@"Installation cancelled"];
                [self setUIEnabled:YES];
                isInstalling = NO;
                [outputPipe release];
                outputPipe = nil;
                [currentTask release];
                currentTask = nil;
                [passwordField release];
                [accessoryView release];
                [alert release];
                return;
            }
            
            [passwordField release];
            [accessoryView release];
            [alert release];
        }
    }
    
    NSFileHandle *outputHandle = [outputPipe fileHandleForReading];
    
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(handleTaskOutput:) 
                                                 name:NSFileHandleReadCompletionNotification 
                                               object:outputHandle];
    
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(handleTaskCompletion:) 
                                                 name:NSTaskDidTerminateNotification 
                                               object:currentTask];
    
    [outputHandle readInBackgroundAndNotify];
    
    @try {
        [currentTask launch];
    }
    @catch (NSException *exception) {
        [self appendToLog:[NSString stringWithFormat:@"Error: %@\n", [exception reason]] 
                withColor:[NSColor redColor]];
        [self setUIEnabled:YES];
        isBuilding = NO;
        isInstalling = NO;
    }
}

- (void)handleTaskOutput:(NSNotification *)notification
{
    NSData *data = [[notification userInfo] objectForKey:NSFileHandleNotificationDataItem];
    
    if ([data length]) {
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (output) {
            [self appendToLog:output];
            [output release];
        }
        
        [[notification object] readInBackgroundAndNotify];
    }
}

- (void)handleTaskCompletion:(NSNotification *)notification
{
    NSTask *task = [notification object];
    int status = [task terminationStatus];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:NSFileHandleReadCompletionNotification 
                                                  object:[[outputPipe fileHandleForReading] autorelease]];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:NSTaskDidTerminateNotification 
                                                  object:task];
    
    if (status == 0) {
        if (isBuilding) {
            [self appendToLog:@"\nBuild completed successfully!\n" withColor:[NSColor greenColor]];
            [self updateStatus:@"Build completed"];
            
            // Update application status
            NSMutableDictionary *app = [[applications objectAtIndex:selectedRow] mutableCopy];
            [app setObject:@"Built" forKey:@"status"];
            [applications replaceObjectAtIndex:selectedRow withObject:app];
            [app release];
            [applicationTableView reloadData];
        } else if (isInstalling) {
            [self appendToLog:@"\nInstallation completed successfully!\n" withColor:[NSColor greenColor]];
            [self updateStatus:@"Installation completed"];
            
            // Update application status
            NSMutableDictionary *app = [[applications objectAtIndex:selectedRow] mutableCopy];
            [app setObject:@"Installed" forKey:@"status"];
            [applications replaceObjectAtIndex:selectedRow withObject:app];
            [app release];
            [applicationTableView reloadData];
            
            // Clean up temp script
            [[NSFileManager defaultManager] removeItemAtPath:@"/tmp/install_app.sh" error:nil];
        }
    } else {
        if (isBuilding) {
            [self appendToLog:@"\nBuild failed!\n" withColor:[NSColor redColor]];
            [self updateStatus:@"Build failed"];
        } else if (isInstalling) {
            [self appendToLog:@"\nInstallation failed!\n" withColor:[NSColor redColor]];
            [self updateStatus:@"Installation failed"];
        }
    }
    
    isBuilding = NO;
    isInstalling = NO;
    [self setUIEnabled:YES];
    
    [outputPipe release];
    outputPipe = nil;
    [currentTask release];
    currentTask = nil;
}

- (void)appendToLog:(NSString *)text
{
    [self appendToLog:text withColor:[NSColor greenColor]];
}

- (void)appendToLog:(NSString *)text withColor:(NSColor *)color
{
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:text];
    [attributedString addAttribute:NSForegroundColorAttributeName 
                              value:color 
                              range:NSMakeRange(0, [text length])];
    [attributedString addAttribute:NSFontAttributeName 
                              value:[NSFont fontWithName:@"Menlo" size:11] 
                              range:NSMakeRange(0, [text length])];
    
    [[logTextView textStorage] appendAttributedString:attributedString];
    [attributedString release];
    
    [logTextView scrollRangeToVisible:NSMakeRange([[logTextView string] length], 0)];
}

- (void)updateStatus:(NSString *)status
{
    [statusLabel setStringValue:status];
}

- (void)setUIEnabled:(BOOL)enabled
{
    [buildButton setEnabled:enabled && (selectedRow >= 0)];
    [installButton setEnabled:enabled && (selectedRow >= 0)];
    [refreshButton setEnabled:enabled];
    [applicationTableView setEnabled:enabled];
    
    if (!enabled) {
        [progressIndicator startAnimation:nil];
    } else {
        [progressIndicator stopAnimation:nil];
    }
}

#pragma mark - NSTableView DataSource/Delegate

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    selectedRow = [applicationTableView selectedRow];
    
    BOOL hasSelection = (selectedRow >= 0);
    [buildButton setEnabled:hasSelection && !isBuilding && !isInstalling];
    [installButton setEnabled:hasSelection && !isBuilding && !isInstalling];
    
    if (hasSelection) {
        NSDictionary *app = [applications objectAtIndex:selectedRow];
        [self updateStatus:[NSString stringWithFormat:@"Selected: %@", [app objectForKey:@"name"]]];
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [applications count];
}

- (id)tableView:(NSTableView *)tableView 
    objectValueForTableColumn:(NSTableColumn *)tableColumn 
    row:(NSInteger)row
{
    if (row >= (NSInteger)[applications count]) {
        return nil;
    }
    
    NSDictionary *app = [applications objectAtIndex:row];
    NSString *identifier = [tableColumn identifier];
    
    return [app objectForKey:identifier];
}

- (NSString *)promptForPassword
{
    // Simple password dialog fallback for GNUstep
    NSPanel *panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 350, 120)
                                                 styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
                                                   backing:NSBackingStoreBuffered
                                                     defer:YES];
    [panel setTitle:@"Administrator Password Required"];
    
    NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 70, 310, 20)];
    [label setStringValue:@"Please enter your password to install:"];
    [label setEditable:NO];
    [label setBordered:NO];
    [label setBackgroundColor:[NSColor clearColor]];
    [[panel contentView] addSubview:label];
    [label release];
    
    NSSecureTextField *passwordField = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(20, 40, 310, 24)];
    [[panel contentView] addSubview:passwordField];
    
    NSButton *okButton = [[NSButton alloc] initWithFrame:NSMakeRect(250, 10, 80, 24)];
    [okButton setTitle:@"OK"];
    [okButton setButtonType:NSMomentaryPushInButton];
    [okButton setBezelStyle:NSRoundedBezelStyle];
    [okButton setTarget:panel];
    [okButton setAction:@selector(stopModalWithCode:)];
    [okButton setTag:NSAlertFirstButtonReturn];
    [[panel contentView] addSubview:okButton];
    [okButton release];
    
    NSButton *cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(160, 10, 80, 24)];
    [cancelButton setTitle:@"Cancel"];
    [cancelButton setButtonType:NSMomentaryPushInButton];
    [cancelButton setBezelStyle:NSRoundedBezelStyle];
    [cancelButton setTarget:panel];
    [cancelButton setAction:@selector(stopModalWithCode:)];
    [cancelButton setTag:NSAlertSecondButtonReturn];
    [[panel contentView] addSubview:cancelButton];
    [cancelButton release];
    
    [panel center];
    [panel makeKeyAndOrderFront:nil];
    
    NSInteger result = [NSApp runModalForWindow:panel];
    NSString *password = nil;
    
    if (result == NSAlertFirstButtonReturn) {
        password = [[passwordField stringValue] retain];
    }
    
    [passwordField release];
    [panel close];
    [panel release];
    
    return [password autorelease];
}

@end
