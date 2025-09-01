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
        
        // Use NSSearchPathForDirectoriesInDomains to respect GNUstep.conf settings
        NSArray *libraryPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        NSString *userLibraryDir = [libraryPaths objectAtIndex:0];
        
        // Set the repo path in user Library directory
        repoPath = [[userLibraryDir stringByAppendingPathComponent:@"gershwin-universe-wrappers"] retain];
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
    
    removeButton = [[NSButton alloc] initWithFrame:NSMakeRect(230, 10, 100, 30)];
    [removeButton setTitle:@"Remove"];
    [removeButton setButtonType:NSMomentaryPushInButton];
    [removeButton setBezelStyle:NSRoundedBezelStyle];
    [removeButton setTarget:self];
    [removeButton setAction:@selector(removeApplication:)];
    [removeButton setEnabled:NO];
    [upperView addSubview:removeButton];
    
    refreshButton = [[NSButton alloc] initWithFrame:NSMakeRect(340, 10, 100, 30)];
    [refreshButton setTitle:@"Refresh"];
    [refreshButton setButtonType:NSMomentaryPushInButton];
    [refreshButton setBezelStyle:NSRoundedBezelStyle];
    [refreshButton setTarget:self];
    [refreshButton setAction:@selector(refreshList:)];
    [upperView addSubview:refreshButton];
    
    // Progress indicator
    progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(450, 15, 20, 20)];
    [progressIndicator setStyle:NSProgressIndicatorSpinningStyle];
    [progressIndicator setDisplayedWhenStopped:NO];
    [upperView addSubview:progressIndicator];
    
    // Status label
    statusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(480, 10, 300, 30)];
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
    [logTextView setFont:[NSFont userFixedPitchFontOfSize:11.0]];
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
        [self appendToLog:@"Repository not found locally. Attempting to clone...\n" 
                withColor:[NSColor yellowColor]];
        [self updateStatus:@"Cloning repository..."];
        
        NSString *parentDir = [repoPath stringByDeletingLastPathComponent];
        
        [[NSFileManager defaultManager] createDirectoryAtPath:parentDir
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
        
        NSTask *gitTask = [[NSTask alloc] init];
        [gitTask setLaunchPath:@"git"];
        [gitTask setArguments:@[@"clone", 
                               @"https://github.com/gershwin-desktop/gershwin-universe-wrappers.git",
                               repoPath]];
        [gitTask setCurrentDirectoryPath:parentDir];
        
        NSPipe *pipe = [NSPipe pipe];
        [gitTask setStandardOutput:pipe];
        [gitTask setStandardError:pipe];
        
        @try {
            [gitTask launch];
            [gitTask waitUntilExit];
            
            if ([gitTask terminationStatus] == 0) {
                [self appendToLog:@"Repository cloned successfully!\n" 
                        withColor:[NSColor greenColor]];
                [self updateStatus:@"Repository ready"];
            } else {
                NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
                NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                [self appendToLog:[NSString stringWithFormat:@"Failed to clone repository:\n%@\n", output] 
                        withColor:[NSColor redColor]];
                [output release];
                [self updateStatus:@"Failed to clone repository"];
                [gitTask release];
                return;
            }
        }
        @catch (NSException *exception) {
            [self appendToLog:[NSString stringWithFormat:@"Error cloning repository: %@\n", [exception reason]] 
                    withColor:[NSColor redColor]];
            [self updateStatus:@"Clone failed - is git installed?"];
            [gitTask release];
            return;
        }
        
        [gitTask release];
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
    
    NSString *appName = [info objectForKey:@"name"];
    if (appName) {
        NSString *installedPath = [NSString stringWithFormat:@"/Applications/%@.app", appName];
        if ([[NSFileManager defaultManager] fileExistsAtPath:installedPath]) {
            [info setObject:@"Installed" forKey:@"status"];
        } else {
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
    
    NSString *gsauthPath = [self findGSAuthPath];
    if (!gsauthPath) {
        [self appendToLog:@"ERROR: gsauth not found!\n" withColor:[NSColor redColor]];
        [self updateStatus:@"gsauth not found"];
        [self setUIEnabled:YES];
        isInstalling = NO;
        
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"gsauth Not Found"];
        [alert setInformativeText:@"The gsauth authentication tool is required but not installed."];
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        [alert release];
        return;
    }
    
    [self runCommand:gsauthPath
       withArguments:@[@"Software Manager", 
                      [NSString stringWithFormat:@"install %@", appName],
                      @"--exec", @"/bin/sh", scriptPath]
         inDirectory:appPath
        requiresAuth:NO];
}

- (void)removeApplication:(id)sender
{
    if (selectedRow < 0 || selectedRow >= (NSInteger)[applications count]) {
        return;
    }
    
    NSDictionary *app = [applications objectAtIndex:selectedRow];
    NSString *appName = [app objectForKey:@"name"];
    NSString *status = [app objectForKey:@"status"];
    
    if (![status isEqualToString:@"Installed"]) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Application Not Installed"];
        [alert setInformativeText:@"This application is not currently installed."];
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        [alert release];
        return;
    }
    
    NSAlert *confirmAlert = [[NSAlert alloc] init];
    [confirmAlert setMessageText:[NSString stringWithFormat:@"Remove %@?", appName]];
    [confirmAlert setInformativeText:[NSString stringWithFormat:@"Are you sure you want to remove %@ from /Applications?", appName]];
    [confirmAlert addButtonWithTitle:@"Remove"];
    [confirmAlert addButtonWithTitle:@"Cancel"];
    
    if ([confirmAlert runModal] != NSAlertFirstButtonReturn) {
        [confirmAlert release];
        return;
    }
    [confirmAlert release];
    
    [self appendToLog:[NSString stringWithFormat:@"\n=== Removing %@ ===\n", appName]];
    [self updateStatus:[NSString stringWithFormat:@"Removing %@...", appName]];
    
    isInstalling = YES;
    [self setUIEnabled:NO];
    
    NSString *scriptPath = @"/tmp/remove_app.sh";
    NSString *scriptContent = [NSString stringWithFormat:
        @"#!/bin/sh\n"
        @"rm -rf '/Applications/%@.app'\n"
        @"echo 'Removed %@.app from /Applications'\n", appName, appName];
    
    [scriptContent writeToFile:scriptPath 
                     atomically:YES 
                       encoding:NSUTF8StringEncoding 
                          error:nil];
    
    chmod([scriptPath UTF8String], 0755);
    
    NSString *gsauthPath = [self findGSAuthPath];
    if (!gsauthPath) {
        [self appendToLog:@"ERROR: gsauth not found!\n" withColor:[NSColor redColor]];
        [self updateStatus:@"gsauth not found"];
        [self setUIEnabled:YES];
        isInstalling = NO;
        
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"gsauth Not Found"];
        [alert setInformativeText:@"The gsauth authentication tool is required but not installed."];
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        [alert release];
        return;
    }
    
    [self runCommand:gsauthPath
       withArguments:@[@"Software Manager", 
                      [NSString stringWithFormat:@"remove %@", appName],
                      @"--exec", @"/bin/sh", scriptPath]
         inDirectory:NSHomeDirectory()
        requiresAuth:NO];
}

- (void)refreshList:(id)sender
{
    [self refreshApplicationList];
}

- (NSString *)findGSAuthPath
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *searchPaths = @[
        @"/usr/local/bin/gsauth",
        @"/opt/local/bin/gsauth",
        @"/usr/bin/gsauth"
    ];
    
    for (NSString *path in searchPaths) {
        if ([fm fileExistsAtPath:path]) {
            return path;
        }
    }
    
    NSTask *configTask = [[NSTask alloc] init];
    [configTask setLaunchPath:@"gnustep-config"];
    [configTask setArguments:@[@"--variable=GNUSTEP_SYSTEM_TOOLS"]];
    
    NSPipe *pipe = [NSPipe pipe];
    [configTask setStandardOutput:pipe];
    
    @try {
        [configTask launch];
        [configTask waitUntilExit];
        
        if ([configTask terminationStatus] == 0) {
            NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
            NSString *toolsPath = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            toolsPath = [toolsPath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            NSString *possiblePath = [toolsPath stringByAppendingPathComponent:@"gsauth"];
            if ([fm fileExistsAtPath:possiblePath]) {
                [toolsPath autorelease];
                [configTask release];
                return possiblePath;
            }
            [toolsPath release];
        }
    }
    @catch (NSException *exception) {}
    
    [configTask release];
    return nil;
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
    
    outputPipe = [[NSPipe alloc] init];
    [currentTask setStandardOutput:outputPipe];
    [currentTask setStandardError:outputPipe];
    
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
            
            NSMutableDictionary *app = [[applications objectAtIndex:selectedRow] mutableCopy];
            [app setObject:@"Built" forKey:@"status"];
            [applications replaceObjectAtIndex:selectedRow withObject:app];
            [app release];
            [applicationTableView reloadData];
        } else if (isInstalling) {
            if ([[NSFileManager defaultManager] fileExistsAtPath:@"/tmp/remove_app.sh"]) {
                [self appendToLog:@"\nRemoval completed successfully!\n" withColor:[NSColor greenColor]];
                [self updateStatus:@"Removal completed"];
                
                NSMutableDictionary *app = [[applications objectAtIndex:selectedRow] mutableCopy];
                [app setObject:@"Not built" forKey:@"status"];
                [applications replaceObjectAtIndex:selectedRow withObject:app];
                [app release];
                [applicationTableView reloadData];
                
                [[NSFileManager defaultManager] removeItemAtPath:@"/tmp/remove_app.sh" error:nil];
            } else {
                [self appendToLog:@"\nInstallation completed successfully!\n" withColor:[NSColor greenColor]];
                [self updateStatus:@"Installation completed"];
                
                NSMutableDictionary *app = [[applications objectAtIndex:selectedRow] mutableCopy];
                [app setObject:@"Installed" forKey:@"status"];
                [applications replaceObjectAtIndex:selectedRow withObject:app];
                [app release];
                [applicationTableView reloadData];
                
                [[NSFileManager defaultManager] removeItemAtPath:@"/tmp/install_app.sh" error:nil];
            }
        }
    } else {
        if (isBuilding) {
            [self appendToLog:@"\nBuild failed!\n" withColor:[NSColor redColor]];
            [self updateStatus:@"Build failed"];
        } else if (isInstalling) {
            if ([[NSFileManager defaultManager] fileExistsAtPath:@"/tmp/remove_app.sh"]) {
                [self appendToLog:@"\nRemoval failed!\n" withColor:[NSColor redColor]];
                [self updateStatus:@"Removal failed"];
            } else {
                [self appendToLog:@"\nInstallation failed!\n" withColor:[NSColor redColor]];
                [self updateStatus:@"Installation failed"];
            }
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
                              value:[NSFont userFixedPitchFontOfSize:11.0] 
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
    [removeButton setEnabled:enabled && (selectedRow >= 0)];
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
    [removeButton setEnabled:hasSelection && !isBuilding && !isInstalling];
    
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

@end
