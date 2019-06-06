#!/bin/sh

GAME_NAME=MyCoolGame
BUNDLE_ID=com.MyCoolCompany.$GAME_NAME
BASE_PATH=/The/Directory/Your/Game/Is/In
EXE_PATH=$BASE_PATH/$GAME_NAME.app/Contents/MacOS/$GAME_NAME
APP_PATH=$BASE_PATH/$GAME_NAME.app
ZIP_PATH=$BASE_PATH/$GAME_NAME.zip
LOG_PATH=Logs

DEV_CERT="FULL DEV CERT NAME GOES HERE"
ENTITLEMENT=example.entitlements
USERNAME=coolguy@coolemail.com
PASSWORD=agoodpassword

UPLOAD_INFO_PLIST=$LOG_PATH/UploadInfo.plist
REQUEST_INFO_PLIST=$LOG_PATH/RequestInfo.plist
AUDIT_INFO_JSON=$LOG_PATH/AuditInfo.json
GAME_INFO_PLIST=example.plist

echo ""
echo "Removing old build..."
rm -rf $APP_PATH/

echo "Moving $GAME_NAME.app..."
mv $BASE_PATH/MacNoEditor/$GAME_NAME.app/ $APP_PATH/

echo "Copying Info.plist..."
cp $GAME_INFO_PLIST $APP_PATH/Contents/Info.plist

# !!!!!! REMOVE THIS IF YOU'RE NOT USING FMOD !!!!!!
echo "Fixing FMOD dylibs..."
install_name_tool -add_rpath @executable_path/../UE4/$GAME_NAME/Plugins/FMODStudio/Binaries/Mac $EXE_PATH

# These rpaths lead to invalid locations. They need to be removed, otherwise the notarized app won't pass the Gatekeeper.
declare -a bad_exe_rpaths=(
	# Some of these are listed twice because they are specified twice, somehow...
	"@loader_path/../../../../../Plugins/FMODStudio/Libs/Mac" # !!!!!! REMOVE THIS IF YOU'RE NOT USING FMOD !!!!!!
	"@loader_path/../../../../../Plugins/FMODStudio/Libs/Mac" # !!!!!! REMOVE THIS IF YOU'RE NOT USING FMOD !!!!!!
	"@loader_path/../../../../../../../UnrealEngine/Engine/Binaries/ThirdParty/PhysX3/Mac" 
	"@loader_path/../../../../../../Engine/Binaries/ThirdParty/PhysX3/Mac"
	"@loader_path/../../../../../../../UnrealEngine/Engine/Binaries/ThirdParty/OpenVR/OpenVRv1_0_16/osx32"
	"@loader_path/../../../../../../Engine/Binaries/ThirdParty/OpenVR/OpenVRv1_0_16/osx32"
	"@loader_path/../../../../../../../UnrealEngine/Engine/Binaries/ThirdParty/Ogg/Mac"
	"@loader_path/../../../../../../Engine/Binaries/ThirdParty/Ogg/Mac"
	"@loader_path/../../../../../../../UnrealEngine/Engine/Binaries/ThirdParty/Vorbis/Mac"
	"@loader_path/../../../../../../Engine/Binaries/ThirdParty/Vorbis/Mac"
	"@executable_path/../../../"
)

for i in "${bad_exe_rpaths[@]}"; do
	echo "Removing bad rpath: $i"
	install_name_tool -delete_rpath $i $EXE_PATH
done

# These dylibs have rpaths that map to a non-existant Fortnite development folder. They need to be removed, otherwise the notarized app won't pass the Gatekeeper.
declare -a bad_fortnite_libs=(
	"libAPEX_Clothing"
	"libAPEX_Legacy"
	"libApexFramework"
	"libNvCloth"
	"libPhysX3"
	"libPhysX3Common"
	"libPhysX3Cooking"
	"libPxPvdSDK"
)

for i in "${bad_fortnite_libs[@]}"; do
	echo "Removing Fortnite rpath from $i.dylib..."
	install_name_tool -delete_rpath /Users/build/Build/++Fortnite/Sync/Engine/Binaries/ThirdParty/PhysX3/Mac $APP_PATH/Contents/UE4/Engine/Binaries/ThirdParty/PhysX3/Mac/$i.dylib
done

# !!!!!! REMOVE IF YOU DON'T GENERATE DEBUG FILES WHEN PACKAGING !!!!!!
echo "Moving dSYM..."
mv $APP_PATH/Contents/UE4/$GAME_NAME/Binaries/Mac/$GAME_NAME-Mac-Shipping.dSYM $BASE_PATH/$GAME_NAME.dSYM

# !!!!!! EVERYTHING BEYOND THIS POINT CAN BE DELETED IF YOU ARE NOT SIGNING YOUR APP BUNDLE !!!!!!

echo "Signing dylibs..."

# Sign all dylibs
for f in $(find ../Builds/macos/$GAME_NAME.app/Contents -name '*.dylib'); do
	codesign --verbose --force --deep --sign "$DEV_CERT" -o runtime --entitlements $ENTITLEMENT --timestamp $f
done

echo "Signing other things..."

# Sign everything else that needs to be signed
declare -a things_to_sign=(
	"$APP_PATH/Contents/UE4/Engine/Build/Mac/RadioEffectUnit/RadioEffectUnit.component"
	"$APP_PATH/Contents/Resources/RadioEffectUnit.component"
	"$APP_PATH/Contents/UE4/Engine/Binaries/Mac/CrashReportClient.app"
	"$APP_PATH"
)

for f in "${things_to_sign[@]}"; do
	codesign --verbose --force --deep --sign "$DEV_CERT" -o runtime --entitlements $ENTITLEMENT $f
done

echo "Zipping for notarization..."
ditto -c -k -v --keepParent $APP_PATH $ZIP_PATH

echo "Sending for notarization..."
xcrun altool --notarize-app --primary-bundle-id "$BUNDLE_ID.zip" -u $USERNAME -p $PASSWORD --file $ZIP_PATH --output-format xml > $UPLOAD_INFO_PLIST

echo "Waiting for notarization..."
xcrun altool --notarization-info `/usr/libexec/PlistBuddy -c "Print :notarization-upload:RequestUUID" $UPLOAD_INFO_PLIST` -u $USERNAME -p $PASSWORD --output-format xml > $REQUEST_INFO_PLIST

while true; do
	xcrun altool --notarization-info `/usr/libexec/PlistBuddy -c "Print :notarization-upload:RequestUUID" $UPLOAD_INFO_PLIST` -u $USERNAME -p $PASSWORD --output-format xml > $REQUEST_INFO_PLIST
	
	if [ `/usr/libexec/PlistBuddy -c "Print :notarization-info:Status" $REQUEST_INFO_PLIST` != "in progress" ]; then
		break
	fi
	
	echo "Checking status: not ready yet..."
	sleep 60s
done

curl -s -o $AUDIT_INFO_JSON `/usr/libexec/PlistBuddy -c "Print :notarization-info:LogFileURL" $REQUEST_INFO_PLIST`
if [ `/usr/libexec/PlistBuddy -c "Print :notarization-info:Status" $REQUEST_INFO_PLIST` != "success" ]; then
	echo "Checking Status: ❌"
	cat $AUDIT_INFO_JSON
	exit
fi

echo "Checking Status: ✅"

echo "Stapling..."
xcrun stapler staple $APP_PATH

echo "Done!"
echo ""