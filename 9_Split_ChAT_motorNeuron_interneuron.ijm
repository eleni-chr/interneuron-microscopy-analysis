/*  STEP 9: SPLIT CHAT CELLS INTO MOTOR NEURONS AND INTERNEURONS

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
  1. Opens the binary mask image ("ch00_MAX_cell_masks.tif") created previously.
  2. Loads all ChAT⁺ cell ROIs from "ch00_MAX_cell_ROIs.zip" into the ROI Manager.
  3. Measures each ROI’s area and classifies them as:
       • Interneurons:  78.5 – 490.9 µm² (10–25 µm)  
       • Motor neurons: 490.9 – 1256.6 µm² (25–40 µm)  
  4. Saves two separate ROI-zip files and measurement CSVs for each group:
       - "ch00_interneurons_ROIs.zip"   &  "ch00_interneurons_measurements.csv"  
       - "ch00_motorNeurons_ROIs.zip"   &  "ch00_motorNeurons_measurements.csv"  
*/

run("Set Measurements...", "area centroid redirect=None decimal=3");
mainDir = getDirectory("Choose main folder containing sub-folders");

firstLevel = getFileList(mainDir);
for (i = 0; i < firstLevel.length; i++) {
    if (!File.isDirectory(mainDir + firstLevel[i])) continue;
    firstDir = mainDir + firstLevel[i] + "/";
    innerList = getFileList(firstDir);
    
    for (j = 0; j < innerList.length; j++) {
        if (!File.isDirectory(firstDir + innerList[j])) continue;
        innerDir = firstDir + innerList[j] + "/";
        
        roiZip   = innerDir + "ch00_MAX_cell_ROIs.zip";
        maskFile = innerDir + "ch00_MAX_cell_masks.tif";
        if (!File.exists(roiZip) || !File.exists(maskFile)) {
            print("  [SKIP] missing ROI zip or mask in " + innerList[j]);
            continue;
        }
        
        print("Processing “" + innerList[j] + "”...");
        
        // 1) Open the mask image
        open(maskFile);
        
        // 2) Load all ROIs
        roiManager("Reset");
        roiManager("Open", roiZip);
        
        // 3) Measure them all
        roiManager("Measure");
        nROIs = roiManager("count");
        
        // Prepare two index‐lists and counters
		smallIdx = newArray();  smallCount = 0;   // interneurons: 78.5–490.9
		largeIdx = newArray();  largeCount = 0;   // motor neurons: 490.9–1256.6
		
		for (r = 0; r < nROIs; r++) {
		    area = getResult("Area", r);
		    if (area >= 78.5 && area <= 490.9) {
		        smallIdx[smallCount++] = r;
		    }
		    else if (area > 490.9 && area <= 1256.6) {
		        largeIdx[largeCount++] = r;
		    }
		    // else: outside both ranges, ignored
		}
        
        // 4a) Save interneuron group if any
        if (smallCount > 0) {
            run("Clear Results");
            roiManager("Select", smallIdx);
            roiManager("Measure");
            saveAs("Results", innerDir + "ch00_interneurons_measurements.csv");
            roiManager("Save Selected", innerDir + "ch00_interneurons_ROIs.zip");
        } else {
            print("  [NOTE] no interneuron‐sized ROIs found.");
        }
        
        // 4b) Save motor‐neuron group if any
        if (largeCount > 0) {
            run("Clear Results");
            roiManager("Select", largeIdx);
            roiManager("Measure");
            saveAs("Results", innerDir + "ch00_motorNeurons_measurements.csv");
            roiManager("Save Selected", innerDir + "ch00_motorNeurons_ROIs.zip");
        } else {
            print("  [NOTE] no motor-neuron‐sized ROIs found.");
        }
        
        // Clean up
        close();                // closes the mask image
        roiManager("Reset");
        print("  Done.\n");
    }
}
print("All done!");
