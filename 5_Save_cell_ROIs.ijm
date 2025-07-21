/* STEP 5: IDENTIFY CELLS TO ANALYSE

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
• The gray matter ROI (saved previously by another macro) is loaded and applied to all images in the subfolder.
• The ROI is used to mask out areas outside the gray matter.
• A threshold (using the “MaxEntropy” method) is applied, with a manual adjustment step to fine-tune the threshold.
• The image is then converted to a binary mask with a black background.
• Noise is reduced using a despeckle filter.
• The macro analyses particles (i.e., cells) to identify them using pre-defined size ranges corresponding to each type of cell stained, adds the corresponding ROIs, and saves cell measurements to a CSV file.
• Cell ROIs and mask images are saved for further analysis of cell distribution within the spinal cord cross-section using another macro.
• If the macro is run again, subfolders that have already been processed are skipped, allowing the user to take a break and resume processing only the remaining subfolders.
*/

// Set measurements for later analysis
run("Set Measurements...", "area centroid redirect=None decimal=3");

// Ask user to select the main folder
mainDir = getDirectory("Choose a Folder");

// Function to count subdirectories in a given directory (for progress output)
function countDirectories(directory) {
    list = getFileList(directory);
    count = 0;
    for(i = 0; i < list.length; i++){
        if(File.isDirectory(directory + list[i])) count++;
    }
    return count;
}

// Count total inner subfolders across all first-level subfolders in the main folder
totalInnerSubfolders = 0;
firstLevelList = getFileList(mainDir);
for(i = 0; i < firstLevelList.length; i++){
    if(File.isDirectory(mainDir + firstLevelList[i])){
        firstLevelDir = mainDir + firstLevelList[i] + "/";
        totalInnerSubfolders = countDirectories(firstLevelDir);
    }
}
print("Total inner subfolders to process: " + totalInnerSubfolders);

innerSubfolderCount = 0;

// Loop through each first-level subfolder in the main folder
for(i = 0; i < firstLevelList.length; i++){
    if(File.isDirectory(mainDir + firstLevelList[i])){
        firstLevelDir = mainDir + firstLevelList[i] + "/";
        innerList = getFileList(firstLevelDir);
        
        // Loop through each inner subfolder
        for(j = 0; j < innerList.length; j++){
            if(File.isDirectory(firstLevelDir + innerList[j])){
                innerDir = firstLevelDir + innerList[j] + "/";
                
                // Check for a marker file that indicates processing is complete
                marker = innerDir + "ch03_MAX_cell_measurements.csv";
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
                
                // Loop through each file in the snapshot list
                for(k = 0; k < originalFileList.length; k++){
                    // Process only files that end with "_MAX.tif"
                    if(endsWith(originalFileList[k], "_MAX.tif"))
                    {
                        // Open image
                        open(innerDir + originalFileList[k]);
                        
                        // Compute base name from current file (remove extension)
                        baseName = substring(originalFileList[k], 0, lengthOf(originalFileList[k]) - 4);
                        
                        // Determine cell type based on filename prefix and set size limits accordingly
                        prefix = substring(originalFileList[k], 0, 4);
                        if(prefix == "ch00"){
                            // ChAT-positive cells: 10-40 µm diameter → area = 78.5–1256.6 µm²
                            sizeLimits = "78.5-1256.6";
                        } else if(prefix == "ch01"){
                            // Calbindin-positive cells: 10-25 µm diameter → area = 78.5–490.9 µm²
                            sizeLimits = "78.5-490.9";
                        } else if(prefix == "ch02"){
                            // GAD-67-positive cells: 8-20 µm diameter → area ≈ 50–314 µm²
                            sizeLimits = "50-314";
                        } else {
                            // Parvalbumin-positive cells: 10-20 µm diameter → area = 78.5–314 µm²
                            sizeLimits = "78.5-314";
                        }
                        
                        // Load the saved gray matter ROI in this inner subfolder
                        roiManager("Reset");
                        roiManager("Open", innerDir + "ch00_MAX_gray_matter.zip");
                        roiManager("Select", 0);
                        
                        // Use the ROI to clear outside (apply mask)
                        run("Clear Outside");
                        
                        // Deselect any selection
                        run("Select None");
                        
                        // Subtract background
                        run("Subtract Background...", "rolling=20");
                                      
                        // Open the threshold adjustment window for manual tweaking
                        run("Threshold...");
                        
                        // Set auto-threshold to use the "MaxEntropy" method.
                        setAutoThreshold("MaxEntropy dark");
                        
                        // Prompt user to manually adjust threshold and click Apply
                        waitForUser("1. Select method MaxEntropy.\n2. Manually adjust the threshold using the Threshold window.\n3. Click Apply.\n4. Click OK to continue.");
                        
                        // Close the threshold adjustment window without closing the image
                        call("ij.plugin.frame.ThresholdAdjuster.close");
                        
                        // Set option to use a black background when converting to mask
                        setOption("BlackBackground", true);
                        
                        // Convert image to mask and save thresholded image using current file's base name
                        run("Convert to Mask");
                        saveAs("Tiff", innerDir + baseName + "_thresh.tif");
                        
                        // Reduce noise using despeckle
                        run("Despeckle");
                        
                        // Apply a morphological closing to fill-in unstained nuclei
                        run("Dilate");
                        run("Erode");
                        run("Fill Holes");

                        // Analyse particles using the size limits determined above
                        run("Analyze Particles...", "size=" + sizeLimits + " show=Masks display add");

                        // Save the cell measurements from the Results table to a CSV file
                        saveAs("Results", innerDir + baseName + "_cell_measurements.csv");
                        
                        // Clear the Results table so that subsequent measurements do not append
                        selectWindow("Results");
                        run("Close");
                        
                        // Save the ROI Manager with the current image's base name appended with "_cell_ROIs"
                        roiManager("Save", innerDir + baseName + "_cell_ROIs.zip");
                        roiManager("Reset");
                        
                        // Save the Masks image with filename appended with "_cell_masks"
                        saveAs("Tiff", innerDir + baseName + "_cell_masks.tif");
                        close();
                        
                        // Close the original image
                        close();
                    }
                }
            }
        }
    }
}
