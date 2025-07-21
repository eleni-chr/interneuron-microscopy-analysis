/* STEP 1: CREATE MAXIMUM PROJECTION IMAGES OF Z-STACKS OF EACH CHANNEL

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
• The macro iterates over the 4 .tif images corresponding to the 4 colour channels (Images must have "Merging_001_" in the filename and have a ".tif" extension).
• It then creates a maximum projection image of the z-stack and saves it with the channel name as the prefix and with the suffix "_MAX".
• If the macro is run again, subfolders that have already been processed are skipped, allowing the user to take a break and resume processing only the remaining subfolders.

*/

// Ask user to select a folder
dir = getDirectory("Choose a Directory");

// Get list of first-level subfolders in the main folder
mainList = getFileList(dir);
for (i = 0; i < mainList.length; i++) {
    // Check if the current item is a folder
    if (File.isDirectory(dir + mainList[i])) {
        subdir = dir + mainList[i] + File.separator;
        // Get list of subfolders within the first-level subfolder
        innerList = getFileList(subdir);
        for (j = 0; j < innerList.length; j++) {
            if (File.isDirectory(subdir + innerList[j])) {
                innerDir = subdir + innerList[j] + File.separator;
                // Check for a file that indicates processing is complete in this inner folder
                if (File.exists(innerDir + "ch03_MAX.tif")) {
                    continue;
                }
                
                files = getFileList(innerDir);
                for (k = 0; k < files.length; k++) {
                    // Process files with "Merging_001_" in the filename and a ".tif" extension
                    if (indexOf(files[k], "Merging_001_") != -1 && endsWith(files[k], ".tif")) {
                        // Determine channel name from filename
                        channel = "";
                        if (indexOf(files[k], "ch00") != -1) {
                            channel = "ch00";
                        } else if (indexOf(files[k], "ch01") != -1) {
                            channel = "ch01";
                        } else if (indexOf(files[k], "ch02") != -1) {
                            channel = "ch02";
                        } else if (indexOf(files[k], "ch03") != -1) {
                            channel = "ch03";
                        }
                        
                        // Open the image
                        open(innerDir + files[k]);
                        
                        // Set scale: one pixel equals 1.136 microns
                        run("Set Scale...", "distance=1 known=1.136 unit=um");
                        
                        // Run max intensity Z-projection
                        run("Z Project...", "projection=[Max Intensity]");
                        
                        // Convert the projection image to 8-bit
                        run("8-bit");
                        
                        // Save the processed image as a TIFF with the channel name appended by "_MAX"
                        saveAs("Tiff", innerDir + channel + "_MAX.tif");
                        
                        // Close the current image(s)
                        close();
                        run("Close All");
                    }
                }
            }
        }
    }
}

