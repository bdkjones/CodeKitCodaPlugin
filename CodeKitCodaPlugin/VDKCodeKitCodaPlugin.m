//
//  VDKCodeKitCodaPlugin.m
//  CodeKitCodaPlugin
//
//  Created by Bryan Jones on 6 Oct 14.
//  Released under the MIT License.

#import "VDKCodeKitCodaPlugin.h"



BOOL isPathAChildOfPath(NSString *proposedChildPath, NSString *proposedParentPath)
{
    NSString *cleanParent = [proposedParentPath stringByStandardizingPath];
    NSString *cleanChild = [proposedChildPath stringByStandardizingPath];
    
    // Does path2 contain path1? (This should be faster than tokenizing the strings on every / and comparing components one by one.
    if (cleanParent && cleanChild && [cleanChild rangeOfString:cleanParent options:NSCaseInsensitiveSearch|NSAnchoredSearch].location != NSNotFound)
    {
        // Do the two paths have different number of components? If not, they're something like:
        // ~/Desktop/Folder and ~/Desktop/Folder2 which are two separate folders, but the second one technically "contains" the first one's path.
        NSUInteger childCount = [[cleanChild pathComponents] count];
        NSUInteger parentCount = [[cleanParent pathComponents] count];
        
        if (childCount > parentCount) {
            return YES;
        }
    }
    
    return NO;
}





@implementation VDKCodeKitCodaPlugin


- (id) initWithPlugInController:(CodaPlugInsController *)aController plugInBundle:(NSObject<CodaPlugInBundle> *)plugInBundle
{
    self = [super init];
    if (self)
    {
        _pluginsController = aController;
        _recentlyHandledPaths = [[NSMutableSet alloc] initWithCapacity:20];
    }
    return self;
}


- (NSString *) name
{
    return @"CodeKit Launcher";
}


- (void) textViewDidFocus:(CodaTextView *)textView
{
    //
    //  Discussion:
    //  Coda 2.5b19 and below have a bug where the 'path' property of textView will be null if we:
    //    1) Drag a folder onto Coda to have it open in a new window.
    //    2) Double-click any file listed in Coda's UI to open it in a textView.
    //
    //  Immediately calling textView.path returns null. As a workaround, we'll let this method return and give Coda
    //  time to get through the current iteration of the runloop so that the 'path' property is set correctly. This is a kludge,
    //  but it works and no user can switch files faster than 0.1s. I've only tested it on modern hardware, though, and can't
    //  guarantee the delay is long enough on ancient Macs. Still, this is better than nothing and prevents the user from thinking
    //  I'm a moron when the plugin doesn't add projects to CodeKit correctly because Coda never gave it the path of the opened file.
    //
    //  I've filed the bug with Panic: https://hive.panic.com/issues/26411 When it's fixed, I'll remove the delay.
    //

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1f * NSEC_PER_SEC)), dispatch_get_main_queue(),
    ^{
        NSString *textViewPath = textView.path;
        if (textViewPath)
        {
            NSString *sitePath = textView.siteLocalPath;        // Must be called on main thread according to Coda API
            
            // Get off the main thread so Coda's UI stays responsive
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0),
            ^{
                NSFileManager *manager = [NSFileManager defaultManager];
                BOOL isFolder = YES;
                NSString *projectPath = nil;

                if (sitePath)
                {
                   // If we have a site open in Coda, then click any random file in the Finder that is NOT part of that site, Coda still opens it in the same
                   // textView and considers it part of the site, which it's really not. We want to make sure this file isn't part of a CodeKit Project that
                   // is NOT the local site path folder; otherwise we'd miss adding the right project folder to CodeKit.
                   if (isPathAChildOfPath(textViewPath, sitePath))
                   {
                       if ([manager fileExistsAtPath:[sitePath stringByAppendingPathComponent:@"config.codekit"] isDirectory:&isFolder] && !isFolder)
                       {
                           projectPath = sitePath;
                       }
                   }
                }


                if (!projectPath)
                {
                   // Walk each folder up from this file and find the first one that has a 'config.codekit' file.
                   NSString *folderToCheck = [textViewPath stringByDeletingLastPathComponent];
                   NSUInteger compsCount = [[folderToCheck pathComponents] count];
                   
                   for (NSUInteger i=0; i<compsCount; i++)
                   {
                       NSString *possibleConfigPath = [folderToCheck stringByAppendingPathComponent:@"config.codekit"];
                       if ([manager fileExistsAtPath:possibleConfigPath isDirectory:&isFolder] && !isFolder)
                       {
                           projectPath = folderToCheck;
                           break;
                       }
                       else
                       {
                           folderToCheck = [folderToCheck stringByDeletingLastPathComponent];
                       }
                   }
                }


                if (projectPath && ![self.recentlyHandledPaths containsObject:projectPath])
                {
                   [self.recentlyHandledPaths addObject:projectPath];
                   
                   dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                       [self.recentlyHandledPaths removeObject:projectPath];
                   });
                   
                   // In my experience, *compiling* AppleScript on a background thread produces no issues, as long as we *execute* it on the main thread.
                   NSDictionary *errorDict = nil;
                   NSString *scriptSource = [NSString stringWithFormat:@"tell application \"CodeKit\" to add project at path \"%@\"", projectPath];
                   
                   NSAppleScript *script = [[NSAppleScript alloc] initWithSource:scriptSource];
                   [script compileAndReturnError:&errorDict];
                   
                   if (errorDict)
                   {
                       NSLog(@"Error encountered while compiling AppleScript Source: %@\nErrorDict: %@", scriptSource, errorDict);
                   }
                   else
                   {
                       // NSAppleScript is not thread-safe IN THE SLIGHTEST. You're going to have a bad day if you run it off the main thread.
                       dispatch_async(dispatch_get_main_queue(),
                                      ^{
                                          NSDictionary *runErrorDict = nil;
                                          [script executeAndReturnError:&runErrorDict];
                                          
                                          if (runErrorDict) {
                                              NSLog(@"Error encountered while running AppleScript Source: %@\nErrorDict: %@", scriptSource, runErrorDict);
                                          }
                                      });
                   }
                }
            });
        }
    });
}

@end
