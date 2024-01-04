default: archive export

[private]
@archive:
	xcodebuild archive -project Tinifimg.xcodeproj -scheme Tinifimg -configuration Release -archivePath ./build/archive

[private]
@export:
	xcodebuild -exportArchive -archivePath ./build/archive.xcarchive -exportPath ./build/export -project Tinifimg.xcodeproj -exportOptionsPlist exportOptions.plist
	
