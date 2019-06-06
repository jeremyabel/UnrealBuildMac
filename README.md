# Fixing Mac Packaging in Unreal Engine 4.22.1

As of Unreal Engine release branch 4.22.1, you cannot generate a working packaged Shipping build directly out of the engine. This script will resolve all the issues with the packaged build. When the script completes, you will have a fixed, signed app bundle that you can distribute to your players!

**Note: This is for MacOS DESKTOP only, not iOS or tvOS!**

## Stuff You'll Need

- Latest XCode, with command line tools installed
- An Apple Developer account
- An Installer Certificate
- An Application Certificate
- A registered Bundle ID for your game

## How To Do It

First, **read through the fixbuild.sh script entirely**! It does a lot of things, including deleting directories! Make sure you understand what it is doing.  There are also a few lines pertaining to FMOD (they are marked) that you will need to remove if you are not using FMOD. 

All the variables you'll need to set are at the top of the script. Various paths are needed, and if you intend on signing your app, you'll need the full name of your Developer Application Certificate, the username for your Apple Developer account, and an App-Specific password.

**Note that if you do not sign your app bundle, the game will not run on other machines unless the Gatekeeper is disabled!**

There's two other files included as well, an Entitlements file an a replacement for the Unreal-provided Info.plist file. The entitlements file will need to be modified with any additional [entitlements](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/AboutEntitlements.html) your game might require. This includes things like enabling desktop notifications, or iCloud support. The plist file will need to be modified with your game's Bundle ID.

Once all your paths and variables are set up in the script, just run it and it'll do the rest!