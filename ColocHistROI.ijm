//a macro to generate 2D histogram of 2 channels in a multi-channel image and generate a mask based on colocalisation
//an image containing the 2D histogram is created and user is prompted to select an ROI
//thereafter a mask is generated and applied on the original image which will mask out all pixels not corresponding to the selected ROI in the histogram
//if no histogram is selected, the macro will close
//works also on stacks
//by Radek Machan, NOBIC, www.nobic.sg

macro "ColocHistROI" {

	LUT = "16 colors"; // LUT for histogram
	CorrectChan = false; //Check whether channles have been selected correctly (not larger than number of channels in the image
	
	getDimensions(wX, hY, ChanNum, NumZ, dummy);
	P = wX*hY*NumZ; //number of pixels
	Orig = getImageID();

	//user settings dialogue
	Dialog.create("Settings");
	Dialog.addNumber("number of channel A:",1); //select 1st channel for the 2D histogram
	Dialog.addNumber("number of channel B:",2); //select 2nd channel for the 2D histogram
	Dialog.addNumber("number of bins - channel A:",256); //number of bins for the first channel
	Dialog.addNumber("number of bins - channel B:",256); //number of bins for the second channel
	Dialog.addCheckbox("use automatc number of bins", true); //overrides numbers of bins set above and sets it to difference between highest and lowest pixel value
	Dialog.show();

	if (ChanNum < 2) {
		Dialog.addMessage("At least 2 channels needed");
		Dialog.show();
	} else {

		while (!CorrectChan) {
			ChanA = Dialog.getNumber;	
			ChanB = Dialog.getNumber;
			BinNumA = Dialog.getNumber;
			BinNumB = Dialog.getNumber;
			AutoBin = Dialog.getCheckbox();
	
			if (ChanA > ChanNum || ChanB > ChanNum) {
				Dialog.addMessage("Wrongly selected channel, larger thannumber of channels");
				Dialog.show();
			} else CorrectChan = true;
		}
			
		if (CorrectChan) {
	
			setBatchMode(true);

			if (NumZ > 1) {
				run("Z Project...", "projection=[Max Intensity]");
				Project =getImageID();
			}

			Stack.setChannel(ChanA);
			getStatistics(dummy, dummy, MinA, MaxA);
			
			if (AutoBin) {
				BinNumA = round(MaxA - MinA)+1; //difference of highest and lowest pixel value - used as a suggestion for number of bins
				S = round(pow(P,1/2));
				if (S < BinNumA) BinNumA = S; // relating number of bins to the number of pixels (for images with low number of pixels)
				if (BinNumA > 256) BinNumA = 256; //Cap the bin number at 256
			}

			Stack.setChannel(ChanB);
			getStatistics(dummy, dummy, MinB, MaxB);
			if (AutoBin) {
				BinNumB = round(MaxB - MinB)+1; //difference of highest and lowest pixel value - used as a suggestion for number of bins
				if (S < BinNumB) BinNumB = S; // relating number of bins to the number of pixels (for images with low number of pixels)
				if (BinNumB > 256) BinNumB = 256; //Cap the bin number at 256
			}

			if (NumZ > 1) {
				selectImage(Project);
				close();
				selectImage(Orig);
			}
		
			newImage("Histogram", "16-bit black", BinNumA, BinNumB,1);
			Hist = getImageID();
			selectImage(Orig);
		
			Aa = newArray(P);  //array for pixel intensities in channel A
			Bb = newArray(P);  //array for pixel intensities in channel B
		
			Stack.setChannel(ChanA);
			for(z=0; z<NumZ; z++) {
				Stack.setSlice(z+1);
				for(y=0; y<hY;y++) {
					for(x=0;x<wX;x++) {
						p= z*wX*hY + y*wX + x;
						Aa[p]=floor((getPixel(x,y)-MinA)/(MaxA - MinA)*(BinNumA-0.1));						
					};
				};
			}
		
			Stack.setChannel(ChanB);
			for(z=0; z<NumZ; z++) {
				Stack.setSlice(z+1);
				for(y=0; y<hY;y++) {
					for(x=0;x<wX;x++) {
						p= z*wX*hY + y*wX + x;
						Bb[p]=floor((getPixel(x,y)-MinB)/(MaxB - MinB)*(BinNumB-0.1));
					};
				};
			}
		
			selectImage(Hist);
			for(p=0; p<P;p++) {
				x = Aa[p];
				y = BinNumB-1-Bb[p];
				val = getPixel(x, y) + 1;
				setPixel(x, y, val);
			};
		
			run (LUT);
			run("Enhance Contrast", "saturated=0.35");
		
			setBatchMode("exit and display");
			
			select = true;
			while(select) {
				waitForUser("ROI selection", "Select ROI in the histogram"); //selection of ROI in the histogram
	
				ChanM = 1;
				if (NumZ > 1) ChanM = ChanNum;
		
				if (selectionType() > -1) {
					newImage("Mask", "8-bit black", wX, hY, ChanM, NumZ, 1);
					Mask = getImageID();
				
					selectImage(Hist);
					Mm = newArray(P);
					for(p=0; p<P;p++) {
						x = Aa[p];
						y = BinNumB-1-Bb[p];
						Mm[p] = 0;
						if (selectionContains(x, y)) Mm[p] = 1;
					}
				
					selectImage(Mask);
					for(z=0; z<NumZ; z++) {
						for (q = 0; q < ChanM; q++) {
							if (NumZ > 1) {
								Stack.setSlice(z+1);
								Stack.setChannel(q+1);
							}
							for(y=0; y<hY;y++) {
								for(x=0;x<wX;x++) {
									p= z*wX*hY + y*wX + x;
									setPixel(x, y, Mm[p]);
								};
							};
						}
						showProgress(z, NumZ);
					}
					
					selectImage(Orig);
					imageCalculator("Multiply create stack", Orig, Mask);
					
					selectImage(Mask);
					close();
					setBatchMode("exit and display");
					
					Dialog.create("Continue?");
					Dialog.addMessage( "Select another ROI?");
					Dialog.show();
				} else select = false;
			}
		}
	}
}



	