/* STEP 4: SAVE GRAY MATTER ROIs

Code written by Dr Eleni Christoforidou.

This ImageJ macro processes images of spinal cord cross-sections stored in a main folder containing multiple subfolders.
Each first-level subfolder contains inner subfolders, where each inner subfolder corresponds to one cross-section imaged over 4 colour channels (each representing a different antibody staining).
E.g.,
MainFolder
	Subfolder1
		InnerSubfolder1
		InnerSubfolder2
		...
	Subfolder2
		InnerSubfolder1
		...

For each inner subfolder:
• The macro iterates over the 4 .tif images corresponding to the 4 colour channels (Images must end with "_MAX.tif").
• In the first image of each subfolder (corresponding to ChAT staining), the user is prompted to draw a region of interest (ROI) around the gray matter. This ROI is saved for later use by the next macro.
• If the macro is run again, subfolders that have already been processed are skipped, allowing the user to take a break and resume processing only the remaining subfolders.
*/

// Ask user to select the main folder
mainDir = getDirectory("Choose a Folder");

// Function to count subfolders in a directory (for progress output)
function countDirectories(directory) {
    list = getFileList(directory);
    count = 0;
    for(i = 0; i < list.length; i++){
        if(File.isDirectory(directory + list[i])) count++;
    }
    return count;
}

// Count total inner subfolders across all first-level subfolders
totalInnerSubfolders = 0;
firstLevelFolders = getFileList(mainDir);
for (i = 0; i < firstLevelFolders.length; i++) {
    if (File.isDirectory(mainDir + firstLevelFolders[i])) {
        firstLevelDir = mainDir + firstLevelFolders[i] + File.separator;
        totalInnerSubfolders = countDirectories(firstLevelDir);
    }
}
print("Total inner subfolders to process: " + totalInnerSubfolders);

innerSubfolderCount = 0;

// Loop through each first-level subfolder in the main folder
for(i = 0; i < firstLevelFolders.length; i++){
    if(File.isDirectory(mainDir + firstLevelFolders[i])){
        firstLevelDir = mainDir + firstLevelFolders[i] + File.separator;
        
        // Get list of inner subdirectories in the first-level folder
        innerList = getFileList(firstLevelDir);
        for(j = 0; j < innerList.length; j++){
            if(File.isDirectory(firstLevelDir + innerList[j])){
                innerDir = firstLevelDir + innerList[j] + File.separator;
                
                // Check for a marker file that indicates processing is complete
                marker = innerDir + "ch00_MAX_gray_matter.zip";
                if (File.exists(marker)) {
                    print("Skipping inner subfolder " + innerList[j] + " because it has already been processed.");
                    continue;
                }
                
                innerSubfolderCount++;
                print("Processing inner subfolder " + innerList[j] + " (" + innerSubfolderCount + " of " + totalInnerSubfolders + ")");
                
                // Get a snapshot list of files that existed in the inner subfolder before processing
                originalFileList = getFileList(innerDir);
                
                // Flag to check if ROI for gray matter has been defined in this inner subfolder
                roiDefined = false;
                firstBaseName = "";
                
                // Loop through each file in the original file list
                for(k = 0; k < originalFileList.length; k++){
                    // Process only files that end with "ch00_MAX.tif"
                    if(endsWith(originalFileList[k], "ch00_MAX.tif"))
                    {
                        // Open image
                        open(innerDir + originalFileList[k]);
                        
                        // Compute base name from current file (remove extension)
                        baseName = substring(originalFileList[k], 0, lengthOf(originalFileList[k]) - 4);
                        
                        // Enhance contrast automatically
                        run("Enhance Contrast", "auto");
                        
                        // Prompt user to draw ROI and save it using its base name.
                        firstBaseName = baseName;
                        waitForUser("Draw around gray matter using the freehand selection tool, then click OK to continue.");
                        
                        // Add the drawn ROI to the ROI Manager
                        run("ROI Manager...");
                        roiManager("reset");
						roiManager("Add");

                        // Save the ROI Manager using the first image's base name with "_gray_matter" appended
                        roiManager("Save", innerDir + firstBaseName + "_gray_matter.zip");
                        roiDefined = true;
                        
                        // Close the image
                        close();
                    }
                }
            }
        }
    }
}
