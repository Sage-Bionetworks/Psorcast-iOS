fastlane documentation
================
# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```
xcode-select --install
```

Install _fastlane_ using
```
[sudo] gem install fastlane -NV
```
or alternatively using `brew cask install fastlane`

# Available Actions
## iOS
### ios keychains
```
fastlane ios keychains
```
Create keychains to store certificates
### ios certificates
```
fastlane ios certificates
```
Fetches provisioning profile and certificates from github repo
### ios noprompt
```
fastlane ios noprompt
```
disable prompt asking for password for codesign to access the keychain
### ios test
```
fastlane ios test
```
Execute tests
### ios archive
```
fastlane ios archive
```
Archive and export app
### ios ci_archive
```
fastlane ios ci_archive
```
This lane is for CI bots to archive and export
### ios bump_all
```
fastlane ios bump_all
```
Bump all the framework projects
### ios bump_build
```
fastlane ios bump_build
```
Bump the build without pushing to TestFlight
### ios beta
```
fastlane ios beta
```
Submit a new Build to appstore
### ios refresh_dsyms
```
fastlane ios refresh_dsyms
```


----

This README.md is auto-generated and will be re-generated every time [fastlane](https://fastlane.tools) is run.
More information about fastlane can be found on [fastlane.tools](https://fastlane.tools).
The documentation of fastlane can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
