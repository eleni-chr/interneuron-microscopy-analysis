/* STEP 6: ANALYSE CELL DISTRIBUTION

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
• The macro opens the image corresponding to the second colour channel (named "ch01_MAX.tif") and prompts the user to draw a freehand ROI around the central canal.
• Calculates the centroid (centre) of the drawn ROI and saves both the ROI and the central canal coordinates in a CSV file in the subfolder.
• Processes each cell mask image in the subfolder by reading corresponding cell measurements (from a CSV file generated in a previous macro).
• For each identified cell, computes the Euclidean distance and angle (in degrees) from the central canal centroid.
• Saves the cell coordinates, distance, and angle data to a new CSV file for further analysis of cell distribution relative to the central canal.
• If the macro is run again, subfolders that have already been processed are skipped, allowing the user to take a break and resume processing only the remaining subfolders.
*/

// --- Process Central Canal for current inner subfolder ---
// Prompt user to select a folder
mainDir = getDirectory("Choose a Folder");

// Get list of first-level subfolders in the main folder
firstLevelList = getFileList(mainDir);
for (i = 0; i < firstLevelList.length; i++) {
    if (File.isDirectory(mainDir + firstLevelList[i])) {
        firstLevelDir = mainDir + firstLevelList[i] + File.separator;
        // Get list of inner subfolders within the first-level folder
        innerList = getFileList(firstLevelDir);
        for (j = 0; j < innerList.length; j++) {
            innerDir = firstLevelDir + innerList[j] + File.separator;
            if (File.isDirectory(innerDir)) {

                // Check for a marker file that indicates cell distribution analysis is complete
                marker = innerDir + "ch03_MAX_distances_angles.csv";
                if (File.exists(marker)) {
                    print("Skipping inner subfolder " + innerList[j] + " because it has already been processed.");
                    continue;
                }
                
                // --- Process the Central Canal ---
                // Open "ch01_MAX.tif" image from the inner subfolder
                open(innerDir + "ch01_MAX.tif");
                        
                // Ask user to draw freehand ROI around the central canal
                waitForUser("Draw around central canal using the freehand selection tool, then click OK.");
                
                // Open ROI Manager and add the current selection
                run("ROI Manager...");
                roiManager("Add");
                
                // Calculate the centroid (center) of the drawn ROI
                getSelectionCoordinates(xpoints, ypoints);
                nPoints = lengthOf(xpoints);
                sumx = 0;
                sumy = 0;
                for (k = 0; k < nPoints; k++) {
                    sumx += xpoints[k];
                    sumy += ypoints[k];
                }
                centerX = sumx / nPoints;
                centerY = sumy / nPoints;
                
                // Save the ROI Manager as a zip file (e.g., "C1_central_canal.zip")
                roiManager("Save", innerDir + "C1_central_canal.zip");
                
                // Save the central canal coordinates in a CSV file in the inner subfolder
                csvPath = innerDir + "Central_canal_coordinates.csv";
                csvLine = innerList[j] + "," + centerX + "," + centerY + "\n";
                if (File.exists(csvPath) == 0) {
                    header = "Subfolder,CenterX,CenterY\n";
                    File.saveString(header, csvPath);
                }
                File.append(csvLine, csvPath);
                
                // Clear selection, reset ROI Manager and close all open images/windows
                run("Select None");
                roiManager("Reset");
                run("Close All"); // Closes open images and any extra windows
                
                // --- Process each cell mask image in this inner subfolder ---
                files = getFileList(innerDir);
                for (k = 0; k < lengthOf(files); k++) {
                    // Only process .tif files that contain "cell_masks" in their name
                    if (endsWith(files[k], "cell_masks.tif")) {
                        // Construct the base name (remove "_cell_masks.tif")
                        base = replace(files[k], "_cell_masks.tif", "");
                        // Construct the cell measurements CSV file name that was produced by the first macro
                        measCSV = innerDir + base + "_cell_measurements.csv";
                        
                        if (File.exists(measCSV)) {
                            // Read the cell measurements CSV file as a string
                            csvText = File.openAsString(measCSV);
                            // Split the CSV text into lines
                            lines = split(csvText, "\n");
                            if (lengthOf(lines) < 2) {
                                print("No data in " + measCSV);
                                continue;
                            }
                            // Assume the first line is the header; split it into fields
                            headerFields = split(lines[0], ",");
                            // Determine indices for the X and Y columns (assumed header names "X" and "Y")
                            xIndex = -1;
                            yIndex = -1;
                            for (l = 0; l < lengthOf(headerFields); l++) {
                                if (trim(headerFields[l]) == "X") {
                                    xIndex = l;
                                }
                                if (trim(headerFields[l]) == "Y") {
                                    yIndex = l;
                                }
                            }
                            if (xIndex == -1 || yIndex == -1) {
                                print("Could not find X and Y columns in " + measCSV);
                                continue;
                            }
                            
                            // Prepare to record cell data from the measurements
                            resultCSV = "Cell,CenterX,CenterY,Distance,Angle\n";
                            
                            // Process each data line (skip header)
                            for (m = 1; m < lengthOf(lines); m++) {
                                line = lines[m];
                                if (lengthOf(trim(line)) == 0) continue; // skip empty lines
                                fields = split(line, ",");
                                cellLabel = fields[0];
                                cellX = parseFloat(fields[xIndex]);
                                cellY = parseFloat(fields[yIndex]);
                                // Calculate Euclidean distance from the central canal
                                dx = cellX - centerX;
                                dy = cellY - centerY;
                                distance = sqrt(dx * dx + dy * dy);
                                // Calculate angle (in degrees)
                                angle = atan2(dy, dx) * 180 / PI;
                                // Convert negative angles to positive (atan2 returns values in the range –180° to 180°)
                                if (angle < 0) {
								    angle = angle + 360;
								}
                                resultCSV += cellLabel + "," + cellX + "," + cellY + "," + distance + "," + angle + "\n";
                            }
                            
                            // Save the distances and angles CSV file using the base name
                            csvName = innerDir + base + "_distances_angles.csv";
                            File.saveString(resultCSV, csvName);
                        } else {
                            print("Cell measurements CSV file not found for " + files[k]);
                        }
                    }
                }
            }
        }
    }
}
