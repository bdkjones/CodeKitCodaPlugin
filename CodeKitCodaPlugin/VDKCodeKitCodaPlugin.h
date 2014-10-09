//
//  VDKCodeKitCodaPlugin.h
//  CodeKitCodaPlugin
//
//  Created by Bryan Jones on 6 Oct 14.
//  Released under the MIT License.
//

#import <Foundation/Foundation.h>
#import "CodaPlugInsController.h"

@class CodaPlugInsController;


@interface VDKCodeKitCodaPlugin : NSObject <CodaPlugIn>
{
    CodaPlugInsController   *_pluginsController;
    
    //
    // Used to rate-limit. If Coda is in the background and user brings it to the front by clicking a different file in the menubar, two -textViewDidFocus events
    // are sent to us virtually simultaneously. Keep paths we notify CodeKit about in this set for 10 seconds so we don't rapid-fire AppleScript events for the same path.
    //
    NSMutableSet            *_recentlyHandledPaths;
}

@property (readonly, atomic) NSMutableSet *recentlyHandledPaths;

@end


//
// Forward Declarations
//
BOOL isPathAChildOfPath(NSString *proposedChildPath, NSString *proposedParentPath);