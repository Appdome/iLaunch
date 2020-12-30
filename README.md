# iLaunch

iLaunch is a command line tool that lets you launch applications on iOS devices connected to your Mac. iLaunch works by using libraries from your local copy of Xcode, meaning it is effectively compatible with any device your copy of Xcode is compatible with.

## Features

iLaunch can do the following:

 * Launch any user-installed or system application
 * Optionally output a launched app's logs to stdout while it's running
 * Pass arguments and environment variables to any launched app
 * Debugging launched applications with `lldb`, as well as attaching to running processes (If they're signed for testing)
 * Show information about the connected devices
 * List the installed apps and their installation directory
 * Extract an application's sandbox
 * Extract crash logs
 * Remove crash logs from the device
 * Take screenshots
 * Use a specific version of Xcode using the `XCODE_PATH` environment variable (Default is /Applications/Xcode.app)
 
## Compilation, Installation and Requirements

To use iLaunch, a copy of Xcode 12 is required. Compilation is done by running `make`; installation is done by running `make install`.

## License

iLaunch is licensed under the [MIT license](LICENSE).
