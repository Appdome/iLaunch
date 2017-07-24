/*

MIT License

Copyright (c) 2017 Appdome ltd.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

/* Classes and APIs used by Xcode */
#include <Foundation/Foundation.h>

@interface IDERunOperationWorker : NSObject
{
    NSString *_extensionIdentifier;
    id _launchSession;
    id _workerGroup;
    BOOL _isLongTerm;
    id _runnableTracker;
}

@property BOOL isLongTerm;
@property(retain, nonatomic) id runnableTracker;
@property(readonly) id launchSession;
@property(readonly) NSString *extensionIdentifier;
@property(retain) id creationBacktrace;
@property(readonly) id invalidationBacktrace;
@property(readonly, nonatomic, getter=isValid) BOOL valid;

- (void)primitiveInvalidate;
- (void)terminate;
- (id)notFinishedReasonWithDepth:(unsigned long long)arg1;
- (void)finishedWithError:(id)arg1;
- (void)start;
- (void)startNextWorkerFromCompletedWorker:(id)arg1 error:(id)arg2;
- (void)setWorkerGroup:(id)arg1;
- (id)initWithExtensionIdentifier:(id)arg1 launchSession:(id)arg2;

@end

@interface IDELaunchiPhoneLauncher : IDERunOperationWorker
{
    id _serviceHubProcessControlChannel;
    id _assetServerChannel;
    id _passcodeLockedToken;
    BOOL _shouldSkipAppTermination;
    int _posixSpawnSTDOUTFDForRedirection;
    BOOL _launchingToDebug;
    id _device;
}

@property(getter=isLaunchingToDebug) BOOL launchingToDebug; // @synthesize launchingToDebug=_launchingToDebug;
@property(retain) id device; // @synthesize device=_device;

+ (unsigned long long)assertionBehaviorAfterEndOfEventForSelector:(SEL)arg1;
- (id)_assetServerChannel;
- (id)_assetServerConnection;
- (void)setupAssetServerWithCompletion:(id /* block */)arg1;
- (BOOL)setupOptimizationProfileGeneration;
- (void)primitiveInvalidate;
- (void)terminate;
- (void)_deviceWoke;
- (void)pidDiedCallback:(NSNumber *)arg1;
- (void)_cancelServiceHubProcessControlChannel;
- (id)_serviceHubProcessControlChannel;
- (id)_bestPrimaryInstrumentsServer;
- (void)_setupPlainLaunching;
- (void)outputReceived:(NSString *)arg1 fromProcess:(int)arg2 atTime:(unsigned long long)arg3;
- (void)_setupDebugging;
- (void)_continueStarting;
- (void)start;
- (void)_holdExecutionWithError:(id)arg1;

@end

@interface IDEExecutionEnvironment : NSObject
- (id)initWithWorkspaceArena:(id)arg1;
@end

@interface IDELaunchParametersSnapshot : NSObject
+ (id)launchParametersWithSchemeIdentifier:(id)arg1 launcherIdentifier:(id)arg2 debuggerIdentifier:(id)arg3 launchStyle:(int)arg4 runnableLocation:(id)arg5 debugProcessAsUID:(unsigned int)arg6 workingDirectory:(id)arg7 commandLineArgs:(id)arg8 environmentVariables:(id)arg9 architecture:(id)arg10 platformIdentifier:(id)arg11 buildConfiguration:(id)arg12 buildableProduct:(id)arg13 deviceAppDataPackage:(id)arg14 allowLocationSimulation:(BOOL)arg15 locationScenarioReference:(id)arg16 showNonLocalizedStrings:(BOOL)arg17 language:(id)arg18 region:(id)arg19 routingCoverageFileReference:(id)arg20 enableGPUFrameCaptureMode:(int)arg21 enableGPUValidationMode:(int)arg22 debugXPCServices:(BOOL)arg23 debugAppExtensions:(BOOL)arg24 internalIOSLaunchStyle:(int)arg25 internalIOSSubstitutionApp:(id)arg26 launchAutomaticallySubstyle:(unsigned long long)arg27;
- (void) setRunnableBundleIdentifier: (NSString*)identifier;
@end

@interface IDERunDestination : NSObject <NSCopying>
- (id)initWithIneligibleTargetDevice:(id)arg1 architecture:(id)arg2 SDK:(id)arg3 deviceIneligibilityError:(id)arg4;
- (id)initWithTargetDevice:(id)arg1 architecture:(id)arg2 SDK:(id)arg3;
@end

@interface IDELaunchSession : NSObject
- (id)initWithExecutionEnvironment:(IDEExecutionEnvironment *)arg1 launchParameters:(IDELaunchParametersSnapshot *)arg2 runnableDisplayName:(NSString *)arg3 runnableType:(id)arg4 runDestination:(IDERunDestination *)arg5;
@end

@interface DTDKRemoteDeviceToken : NSObject
- (id) deviceName;
- (id) deviceSerialNumber;
- (id) deviceClass;
- (id) productVersion;
- (id) deviceArchitecture;
- (NSNumber *) deviceAvailableCapacity;
- (NSNumber *) deviceTotalCapacity;
- (bool) deviceIsActivated;
- (id) startCrashReportCopyMobileServiceWithError:(id *)error;
@end

@interface DVTiOSDevice : NSObject
+ (id)alliOSDevices;
- (NSSet *)applications;
- (NSSet *)systemApplications;
- (NSString *)identifier;
- (DTDKRemoteDeviceToken *) token;
- (id) softwareVersion;
- (bool) isRunningSupportedOS;
- (void) takeScreenshotWithCompletionBlock:(void (^)(NSString *))block;
@end

@interface DVTDeviceManager : NSObject
- (void) startLocating;
- (void) stopLocating;
+ (DVTDeviceManager *) defaultDeviceManager;
- (id) availableDevices;
@end

@interface DVTPlugInManager : NSObject
{
    @public
    id _plugInManagerLock;
    NSFileManager *_fileManager;
    NSString *_hostAppName;
    NSString *_hostAppContainingPath;
    NSMutableArray *_searchPaths;
    NSArray *_extraSearchPaths;
    NSMutableSet *_pathExtensions;
    NSMutableSet *_exposedCapabilities;
    NSMutableSet *_defaultPlugInCapabilities;
    NSMutableSet *_requiredPlugInIdentifiers;
    NSString *_plugInCachePath;
    NSDictionary *_plugInCache;
    BOOL _shouldClearPlugInCaches;
    id _plugInLocator;
    NSMutableDictionary *_plugInsByIdentifier;
    NSMutableDictionary *_extensionPointsByIdentifier;
    NSMutableDictionary *_extensionsByIdentifier;
    NSMutableDictionary *_invalidExtensionsByIdentifier;
    NSMutableSet *_warnedExtensionPointFailures;
    NSMutableSet *_nonApplePlugInSanitizedStatuses;
    NSMutableDictionary *_nonApplePlugInDescriptors;
    NSMutableDictionary *_nonApplePlugInDescriptorActivateCallbacks;
    id _shouldAllowNonApplePlugInsCallback;
}

+ (DVTPlugInManager *)defaultPlugInManager;
- (BOOL)_scanForPlugIns:(id *)arg1;
@end

@interface DVTDeveloperPaths : NSObject
+ (void) initializeApplicationDirectoryName:(NSString*)string;
@end

@interface IDERunnable : NSObject
- (id) runnableUTIType:(id*)what;
- (NSString *) displayName;
@end

@interface IDERemoteRunnable : IDERunnable
- (id)initWithRemotePath:(id)arg1 bundleIdentifier:(id)arg2;
@end

@interface DTDKApplicationItemBase : NSObject
- (NSSet *) children;
- (bool) downloadToFile:(NSString *)path error:(NSError **)error;
@end

@interface DTDKApplication : DTDKApplicationItemBase
- (NSString *) devicePath;
- (NSString *) executableName;
- (NSString *) bundleIdentifier;
- (NSString *) name;
@end

@interface DVTFilePath : NSObject
+(instancetype) filePathForPathString: (NSString *)string;
@end

@interface IDEExecutionRunnableTracker : NSObject
- (id)notFinishedReasonWithDepth:(unsigned long long)arg1;
- (void)executionWantsHold:(BOOL)arg1 withError:(id)arg2;
- (void)runningDidFinish:(id)arg1 withError:(id)arg2;
- (void)cancel;
- (BOOL)isFinished;
- (id)initWithWorker:(id)arg1;
@end

@interface DTDKCrashLogDatabase : NSObject
@end

@interface DTDKCrashLogCopying : NSObject
+(void) checkDevice:(DTDKRemoteDeviceToken *) device;
@end

@interface DVTiPhoneScreenshotController : NSObject
@end

@interface DTDKMobileDeviceToken : NSObject
@end

@interface DVTFuture : NSObject
-(instancetype) initWithResult:(id)result;
@end

extern id (*AFCConnectionCreate)(int unknown, int socket, int unknown2, int unknown3, void *context);
extern int (*AMDServiceConnectionGetSocket)(id connection);
extern void *(*AMDServiceConnectionGetSecureIOContext)(id service);
extern void (*AFCConnectionSetSecureContext)(id connection, void *context);
extern int (*AFCRemovePath)(id connection, const char *path);
extern int (*AFCDirectoryOpen)(id connection, const char *path, id *dir);
extern int (*AFCDirectoryRead)(id connection, id dir, char **dirent);
extern int (*AFCDirectoryClose)(id connection, id dir);