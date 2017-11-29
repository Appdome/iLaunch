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

#include "xcode.h"
#include <objc/runtime.h>
#include <dlfcn.h>

/* This file is responsible to dynamically link against Xcode executables while
   still allowing to use the class name directly (i.e. without objc_getClass,
   etc), as long as that class appears in classes.x. This file also initializes
   Xcode's libraries. */
   
/* Define false classes so we can link statically */
#define X(class, weak) char OBJC_CLASS_$_##class;
#include "classes.x"
#undef X

extern Class classrefs[] __asm("section$start$__DATA$__objc_classrefs");
extern Class classrefs_end __asm("section$end$__DATA$__objc_classrefs");


extern void IDEInitialize(int flags, id *arg1);
extern void IDESetSafeToLoadMobileDevice(void);

id (*AFCConnectionCreate)(int unknown, int socket, int unknown2, int unknown3, void *context);
int (*AMDServiceConnectionGetSocket)(id connection);
void *(*AMDServiceConnectionGetSecureIOContext)(id service);
void (*AFCConnectionSetSecureContext)(id connection, void *context);
int (*AFCRemovePath)(id connection, const char *path);
int (*AFCDirectoryOpen)(id connection, const char *path, id *dir);
int (*AFCDirectoryRead)(id connection, id dir, char **dirent);
int (*AFCDirectoryClose)(id connection, id dir);
int (*AMDeviceSecureStartService)(id device, NSString *service_name, NSDictionary *options, id *result);
int (*AMDeviceStartSession)(id device);
int (*AMDeviceConnect)(id device);

__attribute__((constructor)) static void link_and_init_xcode(void)
{
    /* Allow configuring a specific path to Xcode (for use with betas, etc) */
    NSString *xcode_path = @"/Applications/Xcode.app";
    const char *xcode_path_env = getenv("XCODE_PATH");
    
    if (xcode_path_env) {
        xcode_path = @(xcode_path_env);
    }
    
    
    #define XCODE_REL(x) [[xcode_path stringByAppendingString:(@x)] UTF8String]
    
    /* Create symlinks to Xcode's framework to fix @rpath issues */
    unlink("/tmp/.xcodelib1");
    symlink(XCODE_REL("/Contents/Frameworks"), "/tmp/.xcodelib1");
    unlink("/tmp/.xcodelib2");
    symlink(XCODE_REL("/Contents/SharedFrameworks"), "/tmp/.xcodelib2");
    unlink("/tmp/.xcodelib3");
    symlink(XCODE_REL("/Contents/PlugIns"), "/tmp/.xcodelib3");
    
    /* dlopen whatever we need */

    /* Disable logs (Many irrelevant assertions are printed) */
    int errfd = dup(STDERR_FILENO);
    close(STDERR_FILENO);
    
    int devnull = open("/dev/null", O_WRONLY);
    if (devnull != STDERR_FILENO) {
        dup2(devnull, STDERR_FILENO);
        close(devnull);
    }
    
    if (!dlopen(XCODE_REL("/Contents/Frameworks/IDEFoundation.framework/Versions/A/IDEFoundation"), RTLD_LAZY) ||
        !dlopen(XCODE_REL("/Contents/SharedFrameworks/DVTFoundation.framework/Versions/A/DVTFoundation"), RTLD_LAZY)) {
        /* Enable logs again. */
        dup2(errfd, STDERR_FILENO);
        close(errfd);
        fputs(dlerror(), stderr);
        fputs("\n", stderr);
        exit(1);
    }

    /* initialize "Xcode" */
    typeof(IDEInitialize) *_IDEInitialize
        = dlsym(RTLD_DEFAULT, "IDEInitialize");
    assert(_IDEInitialize);
    typeof(IDESetSafeToLoadMobileDevice) *_IDESetSafeToLoadMobileDevice
        = dlsym(RTLD_DEFAULT, "IDESetSafeToLoadMobileDevice");
    assert(_IDESetSafeToLoadMobileDevice);
    
    id what = nil;
    _IDEInitialize(7, &what);
    _IDESetSafeToLoadMobileDevice();
    
    /* Enable logs again. */
    dup2(errfd, STDERR_FILENO);
    close(errfd);
    
    /* Dlsym C functions we need */
    
    AFCConnectionCreate = dlsym(RTLD_DEFAULT, "AFCConnectionCreate");
    assert(AFCConnectionCreate);
    
    AMDServiceConnectionGetSocket = dlsym(RTLD_DEFAULT, "AMDServiceConnectionGetSocket");
    assert(AMDServiceConnectionGetSocket);
    
    AMDServiceConnectionGetSecureIOContext = dlsym(RTLD_DEFAULT, "AMDServiceConnectionGetSecureIOContext");
    assert(AMDServiceConnectionGetSecureIOContext);
    
    AFCConnectionSetSecureContext = dlsym(RTLD_DEFAULT, "AFCConnectionSetSecureContext");
    assert(AFCConnectionSetSecureContext);
    
    AFCRemovePath = dlsym(RTLD_DEFAULT, "AFCRemovePath");
    assert(AFCRemovePath);
    
    AFCDirectoryOpen = dlsym(RTLD_DEFAULT, "AFCDirectoryOpen");
    assert(AFCDirectoryOpen);
    
    AFCDirectoryRead = dlsym(RTLD_DEFAULT, "AFCDirectoryRead");
    assert(AFCDirectoryRead);
    
    AFCDirectoryClose = dlsym(RTLD_DEFAULT, "AFCDirectoryClose");
    assert(AFCDirectoryClose);
    
    AMDeviceSecureStartService = dlsym(RTLD_DEFAULT, "AMDeviceSecureStartService");
    assert(AMDeviceSecureStartService);

    AMDeviceStartSession = dlsym(RTLD_DEFAULT, "AMDeviceStartSession");
    assert(AMDeviceStartSession);
    
    AMDeviceConnect = dlsym(RTLD_DEFAULT, "AMDeviceConnect");
    assert(AMDeviceConnect);

    
    /* After loading, check for any false class we declared to fix its 
       reference using objc_getClass. */
    Class *classref = classrefs;
    while (classref != &classrefs_end) {
        #define X(class, weak) \
        if (*classref == (Class) &OBJC_CLASS_$_##class) { \
            *classref = objc_getClass(#class);\
            assert((#class && *classref) || weak); \
        }
        #include "classes.x"
        #undef X
        classref++;
    }
}