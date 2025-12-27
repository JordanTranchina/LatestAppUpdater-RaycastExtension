#!/bin/bash

# Configuration
OUTPUT_BINARY="latest-cli"
SWIFT_FLAGS="-DCLI -sdk $(xcrun --show-sdk-path --sdk macosx)"

# Clean up existing artifact
rm -rf "$OUTPUT_BINARY"

echo "Building $OUTPUT_BINARY..."

# Source Files
FILES=(
    # CLI Files
    "Latest/CLI/main.swift"
    "Latest/CLI/LatestCLI.swift"
    "Latest/CLI/CLIAppInfo.swift"
    "Latest/CLI/CLIUpdateChecker.swift"
    "Latest/CLI/CLIInstallManager.swift"
    "Latest/CLI/CLIMASUpdateOperation.swift"
    "Latest/CLI/CommerceKitLite.swift"
    "Latest/CLI/StubOperations.swift"
    "Latest/CLI/SparkleLiteChecker.swift"
    "Latest/CLI/Commands/ListCommand.swift"
    "Latest/CLI/Commands/CheckCommand.swift"
    "Latest/CLI/Commands/InstallCommand.swift"

    # Core Model Files
    "Latest/Model/App.swift"
    "Latest/Model/Bundle.swift"
    "Latest/Model/Source.swift"
    "Latest/Model/Update.swift"
    "Latest/Model/Version/Version.swift"
    "Latest/Model/Version/VersionParser.swift"
    "Latest/Model/Directory/BundleCollector.swift"
    "Latest/Model/Directory/AppLibrary.swift"
    "Latest/Model/Directory/AppDirectory.swift"
    "Latest/Model/Directory/AppDirectoryStore.swift"
    "Latest/Model/AppDataStore.swift"
    "Latest/Model/UpdateCheckCoordinator.swift"
    "Latest/Model/Update Checker Extensions/UpdateCheckerOperation.swift"
    "Latest/Model/Update Repository/UpdateRepository.swift"
    "Latest/Model/Update Repository/UpdateRepository+Entry.swift"
    "Latest/Model/Update Repository/UpdateRepositoryCache.swift"
    "Latest/Model/Utilities/StatefulOperation.swift"
    "Latest/Model/Utilities/FailableDecodable.swift"
    "Latest/Utilities/LatestError.swift"
    
    # Real Checking Operations
    "Latest/Model/Update Checker Extensions/App Store/MacAppStoreCheckerOperation.swift"
    "Latest/Model/Update Checker Extensions/Homebrew/HomebrewCheckerOperation.swift"
    "Latest/Model/Sparkle/Sparkle.swift"

    # Installation Core
    "Latest/Model/Updater/UpdateOperation.swift"
    "Latest/Model/Updater/UpdateQueue.swift"
)

# Run swiftc
swiftc $SWIFT_FLAGS -o "$OUTPUT_BINARY" "${FILES[@]}"

if [ $? -eq 0 ]; then
    # Sign for local execution (required for Apple Silicon)
    codesign -s - "$OUTPUT_BINARY"
    
    # Copy to Raycast extension assets
    ASSETS_DIR="raycast-extension/assets"
    mkdir -p "$ASSETS_DIR"
    cp "$OUTPUT_BINARY" "$ASSETS_DIR/$OUTPUT_BINARY"
    
    echo "--------------------------"
    echo "BUILD SUCCEEDED: $OUTPUT_BINARY"
    echo "COPIED TO: $ASSETS_DIR"
    echo "--------------------------"
else
    echo "--------------------------"
    echo "BUILD FAILED"
    echo "--------------------------"
    exit 1
fi
