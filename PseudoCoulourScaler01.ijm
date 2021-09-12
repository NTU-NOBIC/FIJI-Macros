// A macro for rescaling the visualization of pseudo-colour images and creating a corresponding colour scale bar
// It can open individual TIF images (assumes a monochrome TIF image) or a whole batch of images in a folder
// Scaling can be either absolute by giving minimum and maximum displayed value or relative by disregarding certain fraction of lowest and highest intensity pixels
// For each input iamage a scaled RGB copy is saved along with a coresponding colour scale bar
// Radek Machan, IMCF, NOBIC, radek.machan@ntu.edu.sg, https://www.biocev.eu/en/services/imaging-methods.8, www.nobic.sg 

macro PseudoColourScaler01 {

	// set scaling
	LUTs = getList("LUTs");
	Dialog.create("Pseudo Colour Scaler - settings");
	Dialog.addChoice("LUT", LUTs);
	Dialog.addCheckbox("Use actual min and max", false);
	Dialog.addNumber("Min",0);
	Dialog.addNumber("Max",1);
	Dialog.addCheckbox("Relative scaling", false);
	Dialog.addNumber("Disregard lowest [%]",1);
	Dialog.addNumber("Disregard highest [%]",1);
	Dialog.show();
	
	useLUT = Dialog.getChoice;		// user-selected LUT
	UseImageLim = Dialog.getCheckbox;	// Use min and max of the actual image
	minA = Dialog.getNumber; //absolute minimum
	maxA = Dialog.getNumber; //absolute maximum
	UseRelative = Dialog.getCheckbox;	// Use relative scaling
	minR = Dialog.getNumber; //relative minimum
	maxR = Dialog.getNumber; //relative maximum
	
	// select folder and open files
	folder = getDirectory("Choose Images Directory");
	list = getFileList(folder); 
	setBatchMode(true);

	for (i=0; i < list.length; i++) { 
		if (endsWith(list[i], ".tif") || endsWith(list[i],".tiff" )) {	
			path = folder+list[i];
			run("Bio-Formats Importer", "open=path open_all_series view=Hyperstack stack_order=XYCZT");
			title = getTitle();
			selectImage(title);
			getDimensions(wx, hy, Nchan, Nslice, Nframe);
	
			// loops over all channels of the image - each channel is treated separately, slices and frames are treated together
			for (j=0; j < Nchan; j++) {
				selectImage(title);
				run("Duplicate...", "title=tempIm duplicate channels=" + j+1);
				selectWindow("tempIm");
				
				// determine the actual values of the Min and Max
				minS = minA;
				maxS = maxA;
	
				if (UseImageLim) {
					getMinAndMax(minS, maxS);
				}
	
				if (UseRelative) {
					pixN = wx * hy * Nslice * Nframe;
					pixArray = newArray(pixN);
					rankArray = newArray(pixN);
					q = 0;
					for (k = 0; k < Nslice; k++) {
						if (Nslice > 1) Stack.setSlice(k+1);
						for (l = 0; l < Nframe; l++) {
							if (Nframe > 1) Stack.setFrame(l+1);
							for (x = 0; x < wx; x++) {
								for (y = 0; y < hy; y++) {
									Pixval = getPixel(x,y);
									pixArray[q] = Pixval;
									q++;
								}
							}
						}
					}
					Array.sort(pixArray);
					value = pixArray[0];
					rankArray[0] = 0;
					r = 1;
					for (q = 1; q < pixN; q++) {
						if (pixArray[q] > value) {
							rankArray[r] = q;
							value = pixArray[q];
							r++;
						}
					}
					RankN = r;
					pixL = minR/100 * RankN;
					pixH = maxR/100 * RankN;
					pixRlow = floor(pixL - floor(floor(pixL) - pixL));
					pixRhigh = floor(pixH - floor(floor(pixH) - pixH));
					maxS = pixArray[rankArray[RankN - pixRhigh - 1]];
					minS = pixArray[rankArray[pixRlow]];
				}
	
				// apply LUT and set the scaling
				run(useLUT);
				setMinAndMax(minS, maxS);
				run("RGB Color", "stack");
	
				// save the scaled file
				dotPos = lastIndexOf(list[i], ".");
				nameIm = substring (list[i], 0, dotPos);
				saveAs("tiff", folder + nameIm + "Chan" + j+1 +"_scaledIm.tif");
				close("tempIm");
	
				// generate colour scale bar
				width = 5;
				length = 100;
				newImage("Bar", "32-bit black", length, width, 1);
	
				for (x = 0; x < length; x++) {
					for (y = 0; y < width; y++) {
						value = (maxS-minS)*(x/(length - 1)) + minS;
						setPixel(x,y,value);
					};
				};
				
				run(useLUT);
				setMinAndMax(minS, maxS);
				run("RGB Color");
				setMetadata ("Label","Min=" + minS + ", Max=" + maxS);

				saveAs("tiff", folder + nameIm + "Chan" + j+1 +"_scaleBar.tif");
				close("Bar");
			}
			close(title);
		}
	}
}