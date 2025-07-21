/* STEP 13: ANALYSE CELL DISTRIBUTION FOR DOUBLE-POSITIVE POPULATIONS

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
		
This macro processes only the double-positive cell populations in each inner subfolder, using the central canal centroid already saved by STEP 6.  
For each inner subfolder it:
 1. Reads the central canal coordinates from “Central_canal_coordinates.csv”.  
 2. For each double-positive population:
      • Loads its measurements CSV (e.g. “ChAT_GAD67_double_positive_measurements.csv”)  
      • Computes each cell’s distance & angle from the canal centroid  
      • Writes “<pair_markers>_double_pos_distances_angles.csv” with columns:  
          Cell,CenterX,CenterY,Distance,Angle  
 3. Skips folders already processed.
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
        
        // Skip if already done
        dist1 = innerDir + "ChAT_GAD67_double_pos_distances_angles.csv";
        dist2 = innerDir + "Parvalbumin_GAD67_double_pos_distances_angles.csv";
        dist3 = innerDir + "Parvalbumin_Calbindin_double_pos_distances_angles.csv";
        if (File.exists(dist1) && File.exists(dist2) && File.exists(dist3)) {
            print("Skipping “" + innerList[j] + "”: already processed.");
            continue;
        }
        
        // 1) Read saved canal centroid
        csvPath = innerDir + "Central_canal_coordinates.csv";
        if (!File.exists(csvPath)) {
            print("  [SKIP] no canal coordinates in " + innerList[j]);
            continue;
        }
        csvText = File.openAsString(csvPath);
        lines = split(csvText, "\n");
        if (lengthOf(lines) < 2) {
            print("  [ERROR] incomplete canal CSV in " + innerList[j]);
            continue;
        }
        data = split(lines[1], ",");
        centerX = parseFloat(data[1]);
        centerY = parseFloat(data[2]);
        
        // 2) Process each double-positive population
        subs = newArray("ChAT_GAD67", "Parvalbumin_GAD67", "Parvalbumin_Calbindin");
        for (s = 0; s < lengthOf(subs); s++) {
            pop     = subs[s];
            measCSV = innerDir + pop + "_double_positive_measurements.csv";
            outCSV  = innerDir + pop + "_double_pos_distances_angles.csv";
            
            if (!File.exists(measCSV)) {
				print("  [NOTE] missing measurements for " + pop + " in subfolder " + innerList[j]);
                continue;
            }
            text  = File.openAsString(measCSV);
            lines = split(text, "\n");
            if (lengthOf(lines) < 2) {
                print("  [NOTE] no data in " + measCSV);
                continue;
            }
            hdr = split(lines[0], ",");
			
			// find X and Y column indices
			xIdx = -1; yIdx = -1;
			for (c = 0; c < lengthOf(hdr); c++) {
			    if (trim(hdr[c]) == "X") {
			        xIdx = c;
			    } else if (trim(hdr[c]) == "Y") {
			        yIdx = c;
			    }
			}
			if (xIdx < 0 || yIdx < 0) {
			    print("  [ERROR] X/Y columns not found in " + measCSV);
			    continue;
			}
            
            outText = "Cell,CenterX,CenterY,Distance,Angle\n";
            for (m = 1; m < lengthOf(lines); m++) {
                row = trim(lines[m]);
                if (row == "") continue;
                vals  = split(row, ",");
                cellID = vals[0];
                cellX  = parseFloat(vals[xIdx]);
                cellY  = parseFloat(vals[yIdx]);
                dx = cellX - centerX;
                dy = cellY - centerY;
                dist = sqrt(dx*dx + dy*dy);
                ang  = atan2(dy, dx) * 180 / PI;
                if (ang < 0) ang += 360;
                outText += cellID + "," + cellX + "," + cellY + "," + dist + "," + ang + "\n";
            }
            File.saveString(outText, outCSV);
            print("  Saved distances for " + pop);
        }
    }
}

print("All done!");
