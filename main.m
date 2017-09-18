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

#include <Foundation/Foundation.h>
#include <objc/objc-runtime.h>
#include "xcode.h"

/* Logging and output macros */
#define out(...) puts([[NSString stringWithFormat:__VA_ARGS__] UTF8String])
#define err(fmt, ...) fputs([[NSString stringWithFormat:fmt "\n", ##__VA_ARGS__] UTF8String], stderr)

/* Globals for flags and arguments */
static bool verbose = false;
static bool interactive = true;
static bool wait_for_finish = false;
static NSString *extract_to = nil;
static NSString *screenshot_dest = nil;

/* Obj C hooks we must install */

/* DTDKMobileDeviceToken */
static id copy_shared_cache(DTDKMobileDeviceToken *self, SEL _cmd)
{
    /* This prevents copying the shared cache. We do not need it. */
    return [[DVTFuture alloc] initWithResult:[NSNull null]];
}

/* DVTiPhoneScreenshotController */

static void add_captured_screenshot(DVTiPhoneScreenshotController *self, SEL _cmd, NSData *data)
{
    if (![data writeToFile:screenshot_dest atomically:NO]) {
        err(@"Failed to write screenshot to %@", screenshot_dest);
    }
    exit(0);
}


/* DTDKCrashLogDatabase */

static bool import_crash_logs(Class self, SEL _cmd, NSArray *logs)
{
    for (NSURL *url in logs) {
        if ([[url pathExtension] isEqualToString:@"crash"]) {
            if (verbose) {
                err(@"Copying file %@", url);
            }
            NSError *error = nil;
            [[NSFileManager defaultManager] moveItemAtPath:[url path] toPath:[extract_to stringByAppendingPathComponent:[url lastPathComponent]] error:&error];
            if (error) {
                err(@"Failed to copy file %@ to %@: %@", [url lastPathComponent], extract_to, [error localizedDescription]);
            }
        }
        else {
            if (verbose) {
                err(@"Deleting file %@ (Not a .crash file)", url);
            }
            [[NSFileManager defaultManager] removeItemAtPath:[url path] error:nil];
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        exit(0);
    });
    return false;
}


/* IDELaunchiPhoneLauncher */

static void pid_died_callback(IDELaunchiPhoneLauncher *self, SEL _cmd, NSNumber *pid)
{
    err(@"Proccess %@ died.", pid);
    exit(0);
}

static void output_received(IDELaunchiPhoneLauncher *self, SEL _cmd, NSString *output, int pid, unsigned long long time)
{
    out(@"%@", output);
}

static void set_runnable_pid(IDELaunchiPhoneLauncher *self, SEL _cmd, int pid)
{
    /* Only hooked when not waiting for exit */
    exit(0);
}


/* IDEExecutionRunnableTracker */

static void running_did_finish(IDEExecutionRunnableTracker *self, SEL _cmd, id arg, id error)
{
    err(@"%@: %@", arg, error);
    exit(1);
}

static void execution_wants_hold(IDEExecutionRunnableTracker *self, SEL _cmd, bool hold, NSError *error)
{
    if (!hold) {
        err(@"Continuing...");
        return;
    }
    err(@"%@", [error localizedRecoverySuggestion]);
    if (!interactive) exit(1);
    err(@"%@", [error localizedDescription]);
}

/* Helper functions */

static NSArray *get_devices(bool fast)
{
    NSArray *devices = nil;
    
    size_t old_count = 0;
    if (verbose) {
        err(@"Getting devices");
    }
    
    for (int i = 0; i < 20; i++) {
        /* Xcode gets new devices while the main loop is running */
        [[NSRunLoop mainRunLoop] runUntilDate:[[NSDate date] dateByAddingTimeInterval:0.5]];
        
        /* See how many devices we found */
        devices = [[DVTiOSDevice alliOSDevices] allObjects];
        
        /* If the count hasn't changed (and it's not zero) we're done */
        if ([devices count] == old_count && old_count != 0) {
            break;
        }
        
        /* If fast is true, we don't need all devices; one is enough. */
        if ([devices count] && fast) {
            break;
        }
        
        if (verbose) {
            err(@"...");
        }
        old_count = [devices count];
    }
    
    return devices;
}

void print_device(DVTiOSDevice *device)
{
    out(@"%@:", [device identifier]);
    DTDKRemoteDeviceToken *token = [device token];
    out(@"\tName:             %@",       [token deviceName]);
    out(@"\tSerial:           %@",       [token deviceSerialNumber]);
    out(@"\tClass:            %@",       [token deviceClass]);
    out(@"\tVersion:          %@",       [token productVersion]);
    out(@"\tSoftware Version: %@",       [device softwareVersion]);
    out(@"\tArchitecture:     %@",       [token deviceArchitecture]);
    out(@"\tFree Capacity:    %f/%f GB", [[token deviceAvailableCapacity] doubleValue]  / 1024 / 1024 / 1024, [[token deviceTotalCapacity] doubleValue] / 1024 / 1024 / 1024);
    out(@"\tIs Activated:     %s",       [token deviceIsActivated]? "YES" : "NO");
    out(@"\tIs OS Supported:  %s",       [device isRunningSupportedOS]? "YES" : "NO");
}

void delete_crashes(DVTiOSDevice *device, bool delete_all_crash_logs)
{
    id crash_service = [[device token] startCrashReportCopyMobileServiceWithError:nil];
    void *context = AMDServiceConnectionGetSecureIOContext(crash_service);
    id afc_connection = AFCConnectionCreate(0, AMDServiceConnectionGetSocket(crash_service), 0, 0, 0);
    if (context) {
        AFCConnectionSetSecureContext(afc_connection, context);
    }
    
    id dir = nil;
    AFCDirectoryOpen(afc_connection, ".", &dir);
    for (char *dirent = NULL; AFCDirectoryRead(afc_connection, dir, &dirent), dirent; ) {
        NSString *nsent = @(dirent);
        if ([nsent hasSuffix:@".synced"]) {
            if (verbose) {
                err(@"Removing file at %s", dirent);
            }
            AFCRemovePath(afc_connection, dirent);
        }
        else if (delete_all_crash_logs && [nsent hasSuffix:@".ips"]) {
            if (verbose) {
                err(@"Removing file at %s", dirent);
            }
            AFCRemovePath(afc_connection, dirent);
        }
        else {
            if (verbose) {
                err(@"Skipping %s", dirent);
            }
        }
    }
    AFCDirectoryClose(afc_connection, dir);
}

void launch_app(DVTiOSDevice *device, DTDKApplication *app, NSArray *args, NSDictionary *env)
{
    /* Create runnable */
    IDERemoteRunnable *runnable = [[IDERemoteRunnable alloc] initWithRemotePath:[DVTFilePath filePathForPathString:[app devicePath]]
                                                               bundleIdentifier:[app bundleIdentifier]];
    
    IDERunDestination *destination = [[IDERunDestination alloc] initWithTargetDevice:device architecture:nil SDK:nil];
    
    IDELaunchParametersSnapshot *parameters = [IDELaunchParametersSnapshot
                                           launchParametersWithSchemeIdentifier:nil /*IDEEntityIdentifier*/
                                                             launcherIdentifier:@"Xcode.IDEFoundation.Launcher.PosixSpawn"
                                                             debuggerIdentifier:nil
                                                                    launchStyle:0
                                                               runnableLocation:nil
                                                              debugProcessAsUID:NO
                                                               workingDirectory:nil
                                                                commandLineArgs:args
                                                           environmentVariables:env /* Extermely useful. Can be used to enable debug features of OBJC, DYLD, etc. */
                                                                   architecture:nil /* Can't be used to force 32-bit executables on 64-bit devices :( */
                                                             platformIdentifier:@"com.apple.platform.iphoneos"
                                                             buildConfiguration:@"Debug"
                                                               buildableProduct:nil
                                                           deviceAppDataPackage:nil
                                                        allowLocationSimulation:NO
                                                      locationScenarioReference:nil
                                                        showNonLocalizedStrings:NO
                                                                       language:nil
                                                                         region:nil
                                                   routingCoverageFileReference:nil
                                                      enableGPUFrameCaptureMode:NO
                                                        enableGPUValidationMode:NO
                                                               debugXPCServices:NO
                                                             debugAppExtensions:NO
                                                         internalIOSLaunchStyle:0
                                                     internalIOSSubstitutionApp:nil
                                                    launchAutomaticallySubstyle:2
                                               ];
    
    [parameters setRunnableBundleIdentifier: [app bundleIdentifier]];
    id what = nil;
    IDELaunchSession *session = [[IDELaunchSession alloc] initWithExecutionEnvironment:[[IDEExecutionEnvironment alloc] initWithWorkspaceArena:nil]
                                                                      launchParameters:parameters
                                                                   runnableDisplayName:[runnable displayName]
                                                                          runnableType:[runnable runnableUTIType:&what]
                                                                        runDestination:destination];
    
    method_setImplementation(class_getInstanceMethod([IDELaunchiPhoneLauncher class], @selector(pidDiedCallback:)),
                             (IMP) pid_died_callback);
    method_setImplementation(class_getInstanceMethod([IDELaunchiPhoneLauncher class], @selector(outputReceived:fromProcess:atTime:)),
                             (IMP) output_received);
    if (!wait_for_finish) {
        method_setImplementation(class_getInstanceMethod([IDELaunchSession class], @selector(setRunnablePID:)),
                                 (IMP) set_runnable_pid);
    }
    
    
    IDELaunchiPhoneLauncher *launcher = [[IDELaunchiPhoneLauncher alloc] initWithExtensionIdentifier:@"Xcode.IDEiPhoneOrganizer.Launch" launchSession:session];
    if (verbose) {
        err(@"Launching");
    }
    
    method_setImplementation(class_getInstanceMethod([IDEExecutionRunnableTracker class], @selector(runningDidFinish:withError:)),
                             (IMP) running_did_finish);
    method_setImplementation(class_getInstanceMethod([IDEExecutionRunnableTracker class], @selector(executionWantsHold:withError:)),
                             (IMP) execution_wants_hold);
                             
    IDEExecutionRunnableTracker *tracker = [[IDEExecutionRunnableTracker alloc] initWithWorker:nil];
    [launcher setDevice:device];
    [launcher setRunnableTracker:tracker];
    [launcher start];
    [[NSRunLoop mainRunLoop] run];
}

int main(int argc, const char * argv[])
{
    @autoreleasepool {
        /* Parse args */
        NSString *device_id = nil;
        NSMutableDictionary *env = [[NSMutableDictionary alloc] init];
        NSString *bundle_id = nil;
        NSMutableArray *args = [[NSMutableArray alloc] init];
        bool list = false;
        bool list_devs = false;
        bool extract_crash_logs = false;
        bool delete_crash_logs = false;
        bool delete_all_crash_logs = false;
        
        for (int i = 1; i < argc; i++) {
            const char *arg = argv[i];
            if (i != argc - 1) {
                if (strcmp(arg, "-d") == 0) {
                    i++;
                    device_id = @(argv[i]);
                    continue;
                }
                
                if (strcmp(arg, "-e") == 0) {
                    i++;
                    NSArray *key_value = [@(argv[i]) componentsSeparatedByString:@"="];
                    if ([key_value count] != 2) goto usage;
                    env[key_value[0]] = key_value[1];
                    continue;
                }
                
                if (strcmp(arg, "-x") == 0) {
                    i++;
                    if (list || list_devs || extract_to || delete_crash_logs || screenshot_dest) goto usage;
                    extract_to = @(argv[i]);
                    continue;
                }
                
                if (strcmp(arg, "-L") == 0) {
                    i++;
                    if (list || list_devs || extract_to || delete_crash_logs || screenshot_dest) goto usage;
                    extract_to = @(argv[i]);
                    extract_crash_logs = true;
                    continue;
                }
                
                if (strcmp(arg, "-s") == 0) {
                    i++;
                    if (list || list_devs || extract_to || delete_crash_logs || screenshot_dest) goto usage;
                    screenshot_dest = @(argv[i]);
                    continue;
                }
            }
            
            if (strcmp(arg, "-v") == 0) {
                if (verbose) goto usage;
                verbose = true;
                err(@"Build date: %s %s", __DATE__, __TIME__);
                continue;
            }
            
            if (strcmp(arg, "-w") == 0) {
                if (wait_for_finish) goto usage;
                wait_for_finish = true;
                continue;
            }
            
            if (strcmp(arg, "-n") == 0) {
                if (!interactive) goto usage;
                interactive = false;
                continue;
            }
            
            if (strcmp(arg, "-l") == 0) {
                list = true;
                if (list_devs || delete_crash_logs || extract_to || screenshot_dest) goto usage;
                continue;
            }
            
            if (strcmp(arg, "-D") == 0) {
                list_devs = true;
                if (list || delete_crash_logs || extract_to || screenshot_dest) goto usage;
                continue;
            }
            
            if (strcmp(arg, "-r") == 0) {
                delete_crash_logs = true;
                if (list || list_devs || extract_to || screenshot_dest) goto usage;
                continue;
            }
            
            if (strcmp(arg, "-a") == 0) {
                if (delete_all_crash_logs) goto usage;
                delete_all_crash_logs = true;
                continue;
            }
            
            if (arg[0] == '-') {
                goto usage;
            }
            
            if (bundle_id) {
                [args addObject:@(arg)];
            }
            else {
                bundle_id = @(arg);
            }
        }
        
        method_setImplementation(class_getInstanceMethod([DTDKMobileDeviceToken class] ?: [DTDKRemoteDeviceToken class], @selector(copyAndProcessSharedCache)),
                                 (IMP) copy_shared_cache);
        
        if (!bundle_id != (list || list_devs || extract_crash_logs || delete_crash_logs || screenshot_dest)) {
usage:
            err(@"Usage:");
            err(@"Launch aplication:           %s [-v] [-d device_id] [-n] [-w] [-e ENV=VALUE [-e ENV2=VALUE2 ...]] bundle_id [arg1, ...]", argv[0]);
            err(@"List all applications:       %s [-v] [-d device_id] -l", argv[0]);
            err(@"List all devices:            %s [-v] -D", argv[0]);
            err(@"Extract application data:    %s [-v] [-d device_id] -x output_folder bundle_id", argv[0]);
            err(@"Extract and sync crash logs: %s [-v] [-d device_id] -L output_folder", argv[0]);
            err(@"Remove crash logs:           %s [-v] [-a] [-d device_id] -r", argv[0]);
            err(@"Take screenshot:             %s [-v] [-d device_id] -s output_png", argv[0]);
            err(@"");
            err(@"Flags:");
            err(@"-v: Verbose");
            err(@"-w: Print app's logs and wait until it finishes running.");
            err(@"-n: Non-interactive mode");
            err(@"-a: When using -r, remove all logs, including unsynced logs");
            
            return 1;
        }
        
        
        /* Get devices */
        NSArray *devices = get_devices(!list_devs && !device_id);
        DVTiOSDevice *device;
        
        /* Handle -D */
        if (list_devs) {
            for (DVTiOSDevice *loop_device in devices) {
                print_device(loop_device);
            }
            return 0;
        }
        
        if (device_id == nil) {
            /* User specified no device, take the first one */
            if ([devices count] == 0) {
                err(@"There are no connected devices.");
                return 1;
            }
            device = [devices firstObject];
        }
        else {
            /* User specified a device, try to find it */
            for (DVTiOSDevice *loop_device in devices) {
                if ([[loop_device identifier] isEqualToString:device_id]) {
                    device = loop_device;
                    break;
                }
            }
            if (!device) {
                err(@"Could not find device with identifier: %@", device_id);
                return 1;
            }
        }
        
        /* Handle -r */
        if (delete_crash_logs) {
            delete_crashes(device, delete_all_crash_logs);
            return 0;
        }

        /* Handle -L */
        if (extract_crash_logs) {
            method_setImplementation(class_getClassMethod([DTDKCrashLogDatabase class], @selector(importCrashLogs:)),
                                     (IMP) import_crash_logs);

            [DTDKCrashLogCopying checkDevice:[device token]];
            [[NSRunLoop mainRunLoop] runUntilDate:[[NSDate date] dateByAddingTimeInterval:2]];
            return 0;
        }
        
        /* Handle -s */
        if (screenshot_dest) {
            method_setImplementation(class_getInstanceMethod([DVTiPhoneScreenshotController class], @selector(addCapturedScreenshot:)),
                                     (IMP) add_captured_screenshot);
            
            [device takeScreenshotWithCompletionBlock:^(NSString *unused) {
                /* This block should not be called on a successful scenario since the addCapturedScreenshot hook
                   is called before the block and calls exit. */
                err(@"Failed to take screenshot");
                exit(1);
            }];
            [[NSRunLoop mainRunLoop] run]; /* does not return */
            exit(1); /* Just in case */
        }
        
        if (verbose) {
            err(@"Getting applications");
        }
        
        /* Getting the apps actually happens inside the main loop, but since we're not in the main loop, the first calls will fail. */
        [device applications];
        [device systemApplications];
        [[NSRunLoop mainRunLoop] runUntilDate:[[NSDate date] dateByAddingTimeInterval:1]];
        
        /* Get apps */
        NSArray *applications = [[[device applications] setByAddingObjectsFromSet:[device systemApplications]] allObjects];
        
        /* Choose an app */
        DTDKApplication *app = nil;
        
        /* Handle -l */
        if (list) {
            for (DTDKApplication *loop_app in applications) {
                out(@"%@: (%@ at %@)", [loop_app bundleIdentifier], [loop_app name], [loop_app devicePath]);
            }
            return 0;
        }
        
        /* Get the requested app */
        for (DTDKApplication *loop_app in applications) {
            if ([[loop_app bundleIdentifier] isEqualToString:bundle_id]) {
                app = loop_app;
                break;
            }
        }
        
        if (!app) {
            err(@"Could not find app installed with bundle id: %@", bundle_id);
            return 1;
        }
        
        /* Handle -x */
        if (extract_to)
        {
            NSError *error = nil;
            bool success = [[[[app children] allObjects] firstObject] downloadToFile:extract_to error:nil];
            if (error) {
                err(@"%@", [error localizedRecoverySuggestion]);
                err(@"%@", [error localizedDescription]);
                return 1;
            }
            else if (!success) {
                err(@"Failed for an unknown reason.");
                return 1;
            }
            return 0;
        }
        
        launch_app(device, app, args, env);
    }
    return 0;
}
