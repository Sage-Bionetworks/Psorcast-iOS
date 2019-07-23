#!/bin/sh
set -ex
if [[ "$TRAVIS_PULL_REQUEST" != "false" ]]; then     # on pull requests
    echo "Build on PR"
    FASTLANE_EXPLICIT_OPEN_SIMULATOR=2 bundle exec fastlane test scheme:"Psorcast"
elif [[ -z "$TRAVIS_TAG" && "$TRAVIS_BRANCH" == "master" ]]; then  # non-tag commits to master branch
    echo "Build on merge to master"
    FASTLANE_EXPLICIT_OPEN_SIMULATOR=2 bundle exec fastlane test scheme:"Psorcast"
    bundle exec fastlane keychains
    bundle exec fastlane certificates
    bundle exec fastlane noprompt
    # bundle exec fastlane archive scheme:"Psorcast" export_method:"ad-hoc"
    bundle exec fastlane ci_archive scheme:"Psorcast" export_method:"ad-hoc" project:"Psorcast/Psorcast.xcodeproj"
elif [[ -z "$TRAVIS_TAG" && "$TRAVIS_BRANCH" =~ ^stable-.* ]]; then # non-tag commits to stable branches
    echo "Build on stable branch"
    FASTLANE_EXPLICIT_OPEN_SIMULATOR=2 bundle exec fastlane test scheme:"Psorcast"
    bundle exec fastlane bump_all
    bundle exec fastlane keychains
    bundle exec fastlane certificates
    bundle exec fastlane noprompt
    # bundle exec fastlane archive scheme:"Psorcast" export_method:"ad-hoc"
    bundle exec fastlane ci_archive scheme:"Psorcast" export_method:"ad-hoc" project:"Psorcast/Psorcast.xcodeproj"
fi
exit $?
