/* STEP 11: NORMALISE ChAT⁺ SUBPOPULATION DISTANCES TO GRAY MATTER SIZE

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
		
This macro normalises the previously computed distances of ChAT⁺ interneurons and motor neurons to the gray-matter width for each spinal-cord section.  
For each inner subfolder it:
 1. Finds and opens the channel-0 image (“ch00_MAX.tif”) and its gray-matter ROI (“*_gray_matter.zip”).
 2. Masks to gray matter, computes its Distance Transform, and records the maximum DT value.
 3. For each subpopulation (“interneurons” and “motorNeurons”):
      • Reads “ch00_<subpopulation>_distances_angles.csv”
      • Samples the DT at each cell’s (X,Y) coordinate
      • Computes Normalised_DT = 1 - (DT_distance / maxDT)
      • Writes “ch00_<subpopulation>_DT.csv” with columns:
           Cell,CenterX,CenterY,Distance,Angle,DT_distance,Normalised_DT
 4. Skips any subfolder where both “ch00_interneurons_DT.csv” and “ch00_motorNeurons_DT.csv” already exist.
*/

run("Set Measurements...", "area centroid redirect=None decimal=3");
mainDir = getDirectory("Choose main folder containing sub-folders");

firstLevel = getFileList(mainDir);
for (i = 0; i < firstLevel.length; i++) {
    if (!File.isDirectory(mainDir + firstLevel[i])) continue;
    firstDir = mainDir + firstLevel[i] + File.separator;
    innerList = getFileList(firstDir);

    for (j = 0; j < innerList.length; j++) {
        if (!File.isDirectory(firstDir + innerList[j])) continue;
        innerDir = firstDir + innerList[j] + File.separator;

        // Skip if already normalised
        out1 = innerDir + "ch00_interneurons_DT.csv";
        out2 = innerDir + "ch00_motorNeurons_DT.csv";
        if (File.exists(out1) && File.exists(out2)) {
            print("Skipping “" + innerList[j] + "”: DT files already exist.");
            continue;
        }

        // 1) Open the precomputed ROI-based DT image
        dtFile = innerDir + "ch00_MAX_Distance_Transform.tif";
        if (!File.exists(dtFile)) {
            print("  [SKIP] missing DT image: " + dtFile);
            continue;
        }
        open(dtFile);
        // read max DT for normalisation
        getStatistics(area, mean, min, maxDT, std);
        if (maxDT == 0) {
            print("  [ERROR] Max DT = 0 in “" + innerList[j] + "”; skipping.");
            close();
            continue;
        }
        print("  Max DT in “" + innerList[j] + "”: " + maxDT);

        // 2) Process each subpopulation
        subs = newArray("interneurons", "motorNeurons");
        for (s = 0; s < lengthOf(subs); s++) {
            pop    = subs[s];
            inCSV  = innerDir + "ch00_" + pop + "_distances_angles.csv";
            outCSV = innerDir + "ch00_" + pop + "_DT.csv";

            if (!File.exists(inCSV)) {
                print("    [NOTE] missing measurements for " + pop);
                continue;
            }
            text = File.openAsString(inCSV);
            lines = split(text, "\n");
            if (lengthOf(lines) < 2) {
                print("    [NOTE] no data in " + inCSV);
                continue;
            }

            // parse header to find CenterX/CenterY columns
            hdr = split(lines[0], ",");
            xIdx = -1; yIdx = -1;
            for (c = 0; c < hdr.length; c++) {
                if (trim(hdr[c]) == "CenterX") xIdx = c;
                if (trim(hdr[c]) == "CenterY") yIdx = c;
            }
            if (xIdx < 0 || yIdx < 0) {
                print("    [ERROR] CenterX/CenterY not found in header; skipping " + pop);
                continue;
            }

            // build output CSV with new columns
            outText = lines[0] + ",DT_distance,Normalised_DT\n";
            for (m = 1; m < lengthOf(lines); m++) {
                row = trim(lines[m]);
                if (row == "") continue;
                vals  = split(row, ",");
                cellX = parseFloat(vals[xIdx]);
                cellY = parseFloat(vals[yIdx]);
                dtVal = getPixel(round(cellX), round(cellY));
                // invert so 0 at canal → 1 at boundary
                normVal = 1.0 - (dtVal / maxDT);
                outText += row + "," + dtVal + "," + normVal + "\n";
            }
            File.saveString(outText, outCSV);
            print("    Saved “" + pop + "_DT.csv”");
        }

        // clean up
        close();  // closes DT image
    }
}
print("ChAT subpopulation DT normalisation complete.");