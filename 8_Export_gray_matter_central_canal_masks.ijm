/*  STEP 8: EXPORT GRAY MATTER AND CENTRAL CANAL MASKS AS TIFF FILES

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

For each inner subfolder this macro:
  - Opens the base image "ch00_MAX.tif"
  - Loads the central canal ROI ("C1_central_canal.zip") and uses it to create a binary mask which is saved as "C1_central_canal_mask.tif"
  - Loads the gray matter ROI ("ch00_MAX_gray_matter.zip") and uses it to create a binary mask which is saved as "ch00_MAX_gray_matter_mask.tif"
*/

// Ask user to select a folder
mainDir = getDirectory("Choose main folder containing mouse subfolders: ");
mouseFolders = getFileList(mainDir);

for (i = 0; i < mouseFolders.length; i++) {
    if (File.isDirectory(mainDir + mouseFolders[i])) {
        mouseFolder = mouseFolders[i];
        mousePath = mainDir + mouseFolder + File.separator;
        innerFolders = getFileList(mousePath);
        for (j = 0; j < innerFolders.length; j++) {
            if (File.isDirectory(mousePath + innerFolders[j])) {
                innerFolder = innerFolders[j];
                innerPath = mousePath + innerFolder + File.separator;
                
                // Process only if the base image exists
                if (File.exists(innerPath + "ch00_MAX.tif")) {
                    
                    // --- Process Central Canal ROI ---
                    if (File.exists(innerPath + "C1_central_canal.zip")) {
                        // Open base image to obtain dimensions
                        open(innerPath + "ch00_MAX.tif");
                        run("8-bit");
                        getDimensions(width, height, channels, slices, frames);
                        // Create a new blank image with the same dimensions
                        newImage("Blank", "8-bit black", width, height, 1);
                        selectWindow("Blank");  // make sure the blank image is active
                        
                        // Load the central canal ROI from the zip file.
                        run("ROI Manager...");
                        roiManager("reset");
                        roiManager("Open", innerPath + "C1_central_canal.zip");
                        roiManager("select", 0);
                        setColor("white");
                        run("Fill");
                        
                        // Save the filled (binary mask) image
                        saveAs("Tiff", innerPath + "C1_central_canal_mask.tif");
                        close(); // close the blank image
                        close("ch00_MAX.tif"); // close the base image
                    } else {
                        print("C1_central_canal.zip not found in " + innerPath);
                    }
                    
                    // --- Process Gray Matter ROI ---
                    if (File.exists(innerPath + "ch00_MAX_gray_matter.zip")) {
                        // Re-open the base image
                        open(innerPath + "ch00_MAX.tif");
                        run("8-bit");
                        getDimensions(width, height, channels, slices, frames);
                        newImage("Blank", "8-bit black", width, height, 1);
                        selectWindow("Blank");
                        
                        // Load the gray matter ROI from the zip file
                        run("ROI Manager...");
                        roiManager("reset");
                        roiManager("Open", innerPath + "ch00_MAX_gray_matter.zip");
                        roiManager("select", 0);
                        setColor("white");
                        run("Fill");
                        
                        // Save the filled mask as a TIFF
                        saveAs("Tiff", innerPath + "ch00_MAX_gray_matter_mask.tif");
                        close(); // close the blank image
                        close("ch00_MAX.tif"); // close the base image
                    } else {
                        print("ch00_MAX_gray_matter.zip not found in " + innerPath);
                    }
                } else {
                    print("ch00_MAX.tif not found in " + innerPath);
                }
            }
        }
    }
}

// --- Close all open windows at the end ---
// Close all image windows.
run("Close All");

// Close any remaining ROI Manager window, if open.
winList = getList("window.titles");
for (k = 0; k < winList.length; k++) {
    if (indexOf(winList[k], "ROI Manager") != -1) {
        selectWindow(winList[k]);
        close();
    }
}

print("Processing complete.");
