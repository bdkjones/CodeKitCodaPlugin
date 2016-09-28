//
//  VDKCodeKitCodaPlugin.m
//  CodeKitCodaPlugin
//
//  Created by Bryan Jones on 6 Oct 14.
//  Released under the MIT License.

#import "VDKCodeKitCodaPlugin.h"



BOOL isPathAChildOfPath(NSString *proposedChildPath, NSString *proposedParentPath)
{
    // Clean both paths by stripping any trailing slashes, etc.
    NSString *cleanParent = [proposedParentPath stringByStandardizingPath];
    NSString *cleanChild = [proposedChildPath stringByStandardizingPath];
    
    NSRange commonPrefixRange = [cleanChild rangeOfString:cleanParent options:NSCaseInsensitiveSearch|NSAnchoredSearch];
    
    // Does path2 contain path1? (This should be faster than tokenizing the strings on every / and comparing components one by one.
    if (commonPrefixRange.location != NSNotFound)
    {
        // The child path contains the parent, but it could be a false positive. Example:
        // Parent: /Users/john/desktop/project
        // Child:  /Users/john/desktop/project-other/file.js
        // If child is truly part of parent, then the character AFTER the commonPrefixRange *must* be a slash.
        NSUInteger nextCharacterLocation = commonPrefixRange.location + commonPrefixRange.length;
        if (nextCharacterLocation < cleanChild.length)
        {
            unichar character = [cleanChild characterAtIndex:nextCharacterLocation];
            return (character == '/') ? YES : NO;
        }
        else
        {
            // Can't possibly be a child. Proposed child and parent must be equal.
            return NO;
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
    //  Coda 2.5b19 and below have a bug where immediately calling [textView path] returns null in some cases.
    //  As a workaround, we'll let this method return and get to the next iteration of the runloop so that the
    //  'path' property is set correctly. I filed this with Panic at https://hive.panic.com/issues/26411 and Wade
    //  used this approach to fix this issue for Coda 2.5+. I want to cover older versions of Coda 2, so I've left the
    //  first 'dispatch_after' call in place. Eventually, it should be removed when no one uses earlier versions of Coda.
    //

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0), dispatch_get_main_queue(),
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
                       if (([manager fileExistsAtPath:[sitePath stringByAppendingPathComponent:@"config.codekit3"] isDirectory:&isFolder] && !isFolder)
                           || ([manager fileExistsAtPath:[sitePath stringByAppendingPathComponent:@"config.codekit"] isDirectory:&isFolder] && !isFolder))
                       {
                           projectPath = sitePath;
                       }
                   }
                }


                if (!projectPath)
                {
                   // Walk each folder up from this file and find the first one that has a 'config.codekit3' file.
                   NSString *folderToCheck = [textViewPath stringByDeletingLastPathComponent];
                   NSUInteger compsCount = [[folderToCheck pathComponents] count];
                   
                   for (NSUInteger i=0; i<compsCount; i++)
                   {
                       NSString *possibleConfigPath = [folderToCheck stringByAppendingPathComponent:@"config.codekit3"];
                       if (([manager fileExistsAtPath:possibleConfigPath isDirectory:&isFolder] && !isFolder)
                           || ([manager fileExistsAtPath:[folderToCheck stringByAppendingPathComponent:@"config.codekit"] isDirectory:&isFolder] && !isFolder))
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
                       NSLog(@"The CodeKit Plugin encountered an error while compiling AppleScript Source: %@\nErrorDict: %@", scriptSource, errorDict);
                   }
                   else
                   {
                       // NSAppleScript is not thread-safe IN THE SLIGHTEST. You're going to have a bad day if you run it off the main thread.
                       dispatch_async(dispatch_get_main_queue(),
                                      ^{
                                          NSDictionary *runErrorDict = nil;
                                          [script executeAndReturnError:&runErrorDict];
                                          
                                          if (runErrorDict) {
                                              NSLog(@"The CodeKit Plugin encountered an error while running AppleScript Source: %@\nErrorDict: %@", scriptSource, runErrorDict);
                                          }
                                      });
                   }
                }
            });
        }
    });
}

@end
