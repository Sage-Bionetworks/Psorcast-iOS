#!/bin/sh
set -ex
if [[ "$TRAVIS_PULL_REQUEST" != "false" ]]; then     # on pull requests
    echo "Build on PR"
    # FASTLANE_EXPLICIT_OPEN_SIMULATOR=2 bundle exec fastlane test scheme:"Psorcast"
    # FASTLANE_EXPLICIT_OPEN_SIMULATOR=2 bundle exec fastlane test scheme:"PsorcastValidation"
elif [[ -z "$TRAVIS_TAG" && "$TRAVIS_BRANCH" == "master" ]]; then  # non-tag commits to master branch
    echo "Build on merge to master"
    git clone https://github.com/Sage-Bionetworks/iOSPrivateProjectInfo.git ../iOSPrivateProjectInfo
    # FASTLANE_EXPLICIT_OPEN_SIMULATOR=2 bundle exec fastlane test scheme:"Psorcast"
    FASTLANE_EXPLICIT_OPEN_SIMULATOR=2 bundle exec fastlane test scheme:"PsorcastValidation"
    bundle exec fastlane keychains
    bundle exec fastlane certificates
    bundle exec fastlane noprompt
    bundle exec fastlane ci_archive scheme:"Psorcast" export_method:"app-store" project:"Psorcast/Psorcast.xcodeproj"
    bundle exec fastlane ci_archive scheme:"PsorcastValidation" export_method:"app-store" project:"Psorcast/Psorcast.xcodeproj"
elif [[ -z "$TRAVIS_TAG" && "$TRAVIS_BRANCH" =~ ^stable-.* ]]; then # non-tag commits to stable branches
    echo "Build on stable branch"
    git clone https://github.com/Sage-Bionetworks/iOSPrivateProjectInfo.git ../iOSPrivateProjectInfo
    # FASTLANE_EXPLICIT_OPEN_SIMULATOR=2 bundle exec fastlane test scheme:"Psorcast"
    FASTLANE_EXPLICIT_OPEN_SIMULATOR=2 bundle exec fastlane test scheme:"PsorcastValidation"
    bundle exec fastlane bump_all
    bundle exec fastlane keychains
    bundle exec fastlane certificates
    bundle exec fastlane noprompt
    bundle exec fastlane ci_archive scheme:"Psorcast" export_method:"app-store" project:"Psorcast/Psorcast.xcodeproj"
    bundle exec fastlane beta scheme:"PsorcastValidation" export_method:"app-store" project:"Psorcast/Psorcast.xcodeproj"
fi
exit $?
