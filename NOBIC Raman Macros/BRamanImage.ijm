//a macro to generate images from raster scans taken with NOBIC Raman/Brillouin microscope
//Raman image rendering is identical to RamanImage macro.
//Simultaneously a Brillouin image is rendered from simulatenouslly acquired spectra (saved as a time series)
//by Radek MACHAN, NOBIC, www.nobic.sg

macro "BRamanImage" {

	MaxChan = 5; //max.number of channels, currently max. 5 supported by other definitions (LUTs, starts and ends)
	//definition of channels for Raman image - start and end in /cm
	Chanstart = newArray(3200, 2800, 830, 1020, 1600);
	Chanend = newArray(3600, 3000, 960, 1050, 1700);
	Chansel = newArray(false, true, false, false, false);
	LUT = newArray("Cyan", "Magenta", "Yellow", "Green", "Red");

	Dialog.create("Settings");
	Dialog.addCheckbox("subtract baseline", true);
	Dialog.addCheckbox("process Brillouin spectra", true);
	Dialog.addNumber("X pixel size in um", 1);
	Dialog.addNumber("Y pixel size in um", 1);
	Dialog.addMessage("Raman channels definitions");
	for (i = 0; i < MaxChan; i++) { //Raman channels definitions
		Dialog.addCheckbox("Channel "+i, Chansel[i]);
		Dialog.addNumber("Start *cm", Chanstart[i]);
		Dialog.addNumber("End *cm", Chanend[i]);
	}
	Dialog.addCheckbox("show advanced settings", false);
	Dialog.show();

	baseline = Dialog.getCheckbox(); //subtract baseline
	Brillouin = Dialog.getCheckbox(); //process Brillouin spectra
	PixSizeX = Dialog.getNumber(); //pixel size (raster scan step) in um
	PixSizeY = Dialog.getNumber(); //pixel size (raster scan step) in um
	ChanN = 0; 
	for (i = 0; i < MaxChan; i++) {
		Chansel[i] = Dialog.getCheckbox;
		Chanstart[i] = Dialog.getNumber;
		Chanend[i] = Dialog.getNumber;
		if(Chansel[i]) ChanN++;
	}
	Chans = newArray(ChanN); //array to hold numbers of selected channels
	ch = 0;
	for (i = 0; i < MaxChan; i++) { //find which channels have been selected
		if (Chansel[i]){
			Chans[ch] = i;
			ch++;
		}
	}
	Advanced = Dialog.getCheckbox(); //enter advanced settings

	//definitions related to Brillouin spectra
	BLUT = "16 colors";
	meander = false; //meander scan, lines first
	
	//definitions for Brillouin processing
	ROIh = 40; //ROI height
	ROIy = 56; //y coordinate of ROI start
	Roff = 4; //offset in frequency of search ROI from main Rayleigh peak
	R1 = 384; //absolute pixel position of main Rayleigh peak
	Brescale = 10; //rescaling factor of the Brillouin image 
	FSR = 30; //Free spectral range in GHz
	Smot = 3; //smoothing diameter in pixels
	maxSearch = false;
	//parameters for maxima search
	diffTol = 0.1; //tolerance on Brillouin peak position difference
	PeakProm = 10; //Brillouin peak prominance for maxima search
	PeakW = 10; //Brillouin peak half-width for peak integration
	//baseline subtraction parameters
	Binit = 10; //length in pixels of the initial region assumed to be free of peaks
	Bpoints = 5; //number of minima points in each half of the spectrum
	BBCurve = 5; //polynomial degree
	BBCurveN = "5th Degree Polynomial"; //polynomial degree
	//frequency calibration
	a = 4E-5;
	b = 0.118;
	calPeak = true; //calibrate the position of the main Rayleigh peak
	internCalib = true; //use the stack itself for calibration
	//derived parameters:
	ROIw = FreqToPix(FSR-Roff) - FreqToPix(Roff); //ROI width
	if (ROIw/2 != round(ROIw/2)) ROIw ++;
	//

	ChanStart = newArray(ChanN); //channels starts in pixels
	ChanEnd = newArray(ChanN); //channels ends in pixels

	BckgR = 95; //Raman camera offset
	BckgB = 95; //Brillouin camera offset
	ZoomNum = 7; //how many times should the image be zoomed in

	//parameters of x-axis calibration - needed to recalculate channel start/end to pixels
	slope = 0.1292;   
	offset = 577.35;  // specific values determined by spectrometer calibration using organic compounds of well-known Raman spectra
	pixNum = 1024;   // number of camera pixels
	laser = 561;   //laser wavelength in nm

	//spike removal parameters
	SpikeWidth = 3; //maximum spike width in pixels, 3 or 5 recommended
	SpikeThreshold = -70; //Threshold in 2nd differential image to identify spikes
	SpikeThreshold2 = 40; //Threshold of neighbouring pixel in 2nd differential image to identify spikes
	Val = newArray(2*SpikeWidth-1); //array for despiking

	//baseline removal setting and definitions:
	SegNum = 3; //number of segments within signature region
	Points = 5; //number of baseline points/segment within fingerprint region
	BCurve = 6; //polynomial degree
	BCurveN = "6th Degree Polynomial"; //polynomial degree

	ignoreInit = true; //ignore the first initial empty region - outside of spectrum range

	Water1StartS = 3050; //Start for water peak integration
	Water1EndS = 3350; //Start for water peak integration1
	Water2StartS = 3250; //Start for water peak integration2
	Water2End = pixNum; //End for water peak integration
	WaterDivS = 3100; //ending point for fitting silent region baseline

	SilentStartS = 1850; //Start for silent region integration
	SilentEndS = 2750; //End for silent region integration
	SilentDivS = 2700; //Starting point for fitting water peak baseline

	InitEnd = 30; //end of initial empty region; 20 - 30 px. 

	Water1Start = ShifToPix(Water1StartS);
	Water2Start = ShifToPix(Water2StartS);
	Water1End = ShifToPix(Water1EndS);
	WaterDiv = ShifToPix(WaterDivS);
	SilentStart = ShifToPix(SilentStartS); 
	SilentEnd = ShifToPix(SilentEndS);
	SilentDiv = ShifToPix(SilentDivS);

	if (Advanced) {
		Dialog.create("Advanced Settings");
		Dialog.addMessage("Despiking settings:");
		Dialog.addNumber("max. spike width in px.", SpikeWidth);
		Dialog.addNumber("spike threshold in 2nd diff image", SpikeThreshold); 
		Dialog.addNumber("neighbouring pixels threshold in 2nd diff image", SpikeThreshold2); 
		Dialog.addMessage("Baseline subtraction settings:");
		Dialog.addCheckbox("ignore initial segment", ignoreInit);
		Dialog.addNumber("number of segments in signature region:", SegNum ); 
		Dialog.addNumber("number of points per segment:", Points ); 
		if (Brillouin) {
			Dialog.addMessage("Brillouin settings:");
			Dialog.addCheckbox("meander scan rows first (original M-M rastering tool)", meander );
			Dialog.addCheckbox("calibrate main Rayleigh peak", calPeak );
			Dialog.addCheckbox("use the Stack itself for calibration", internCalib );
			Dialog.addCheckbox("perform maxima search", maxSearch );		
		} 
		Dialog.show();

		SpikeWidth = Dialog.getNumber();
		SpikeThreshold = Dialog.getNumber();
		SpikeThreshold2 = Dialog.getNumber();
		ignoreInit = Dialog.getCheckbox();
		SegNum = Dialog.getNumber();
		Points = Dialog.getNumber();
		if (Brillouin) {
			meander = Dialog.getCheckbox;
			calPeak = Dialog.getCheckbox;
			internCalib = Dialog.getCheckbox;
			maxSearch = Dialog.getCheckbox;		
		} 
	}

	//arrays for baseline subtraction
	Basenum0 = InitEnd + SilentDiv - SilentStart + Points*SegNum;
	Basenum1 = SilentEnd - SilentStart + WaterDiv - Water1Start + Points*SegNum;
	Basenum2 = Water1End - Water1Start + SilentEnd - SilentDiv;
	Basenum3 = Water2End - Water2Start;
	DivDist0 = SilentStart - InitEnd;
	DivDist = WaterDiv-Water1Start;
	DivDistW = Water1End-Water2Start;
	Baseline=newArray(pixNum);
	Baseline0=newArray(pixNum);
	Baseline1=newArray(pixNum);
	Baseline2=newArray(pixNum);
	Baseline3=newArray(pixNum);
	BaseX0=newArray(Basenum0);
	BaseY0=newArray(Basenum0);
	BaseX1=newArray(Basenum1);
	BaseY1=newArray(Basenum1);
	BaseX2=newArray(Basenum2);
	BaseY2=newArray(Basenum2);
	BaseX3=newArray(Basenum3);
	BaseY3=newArray(Basenum3);
	Min = newArray(Points);

	BBaseline=newArray(ROIw);
	BBaseline1=newArray(ROIw);
	BBaseline2=newArray(ROIw);
	BMin = newArray(Bpoints);
	BBaseX1=newArray(Binit + 4*Bpoints);
	BBaseY1=newArray(Binit + 4*Bpoints);
	BBaseX2=newArray(Binit + 4*Bpoints);
	BBaseY2=newArray(Binit + 4*Bpoints);

	//recalculate channels definitions to pixels
	for (n = 0; n < ChanN; n++) {
		ChanStart[n] = ShifToPix(Chanstart[Chans[n]]);
		ChanEnd[n] = ShifToPix(Chanend[Chans[n]]);
	}
	print("\\Clear"); //clear the log

	//user input
	DirR = getDirectory("Raman Folder"); // Raman data folder
	if(Brillouin) {
		Bpath = File.openDialog("Brillouin Stack"); // Brilluoin spectra stack	
		open(Bpath);
		Bstack = getImageID();
		if (calPeak) {
			if (!internCalib) { //find the absolute pixel position of the main Rayeigh peak and update R1
				waitForUser("Peak position calibration", "select a spectrum for calibration of Rayleigh peak positions");
				CalIm = getImageID();
			} else {
				selectImage(Bstack);
			}
			setBatchMode(true);
			if (nImages > 0) {
				getDimensions(CalW, dummy, dummy, dummy, dummy);
				makeRectangle(0, ROIy, CalW, ROIh);
				run("Scale...", "x=- y=- width="+CalW+" height=1 interpolation=Bilinear average create");   		
				run("Clear Results");
				run("Find Maxima...", "prominence="+2*PeakProm+" output=List"); //Find maxima
				if(nResults < 1) {
					print("no calibration performed");
				} else {
					Ra = getResult("X", 0);
					Rb = getResult("X", 1);
					R1 = Ra;
					if (Rb < Ra) R1 = Rb;
					print("R1 = "+R1);
				}
				close();
				if(!internCalib) {
					if (isOpen(CalIm)) {
						selectImage(CalIm);
						close();
					}
				}
			} else {
				print("no calibration performed");
			}
		}
	}
		
	setBatchMode(true);
	run("Conversions...", "scale");
	
	//prepare for looping through directory
	listR = getFileList(DirR);
	MR = listR.length;
	if (Brillouin){
		selectImage(Bstack);
		getDimensions(Bwidth, Bheight, dummy, dummy, MB);
	}

	//loop through the directory to determine the raster size
	Xmax = 0; //largest x coordinate
	Ymax = 0; //largest y coordinate
	for (m=0; m<MR; m++) {//read file name and retrieve coordinates	
		XInd = indexOf(listR[m], "X");
		YInd = indexOf(listR[m], "Y");
		if(XInd > -1) {
			Xs = substring(listR[m], XInd + 1, XInd + 4);
			X = parseInt(Xs);
			if (X > Xmax) Xmax = X;
			Ys = substring(listR[m], YInd + 1, YInd + 4);
			Y = parseInt(Ys);
			if (Y > Ymax) Ymax = Y;
   		}
	}

	//generate output images
	newImage("Raman", "32-bit black", Xmax+1, Ymax+1, ChanN, 1, 1);
	RamanIm = getImageID();
	run("Properties...", " pixel_width="+PixSizeX+" pixel_height="+PixSizeY);
	Stack.setXUnit("um");
	Stack.setYUnit("um");
	
	if(Brillouin) {
		newImage("Brillouin shift", "8-bit black", Xmax+1, Ymax+1, 1, 1, 1);
		BrIm = getImageID();
		run("Properties...", " pixel_width="+PixSizeX+" pixel_height="+PixSizeY);
		Stack.setXUnit("um");
		Stack.setYUnit("um");
		selectImage(Bstack); //do Brillouin spectrum processing
		makeRectangle(R1+FreqToPix(Roff), ROIy, ROIw, ROIh);
		run("Scale...", "x=- y=- z=- width="+ROIw+" height=1 depth="+MB+" interpolation=Bilinear average process create");
		run("Subtract...", "value="+BckgB+ " stack");
		BSpect = getImageID();
   		//smoothen the spectrum
		run("Median...", "radius="+ Smot +" stack");
		selectImage(Bstack);
		close();
		newImage("Baseline", "16-bit blaclk", ROIw, 1, MB);
		BaselineIm = getImageID();
	}
		
	//loop again through the images in the directory to contruct the output images
	point = -1;
	for (m=0; m<MR; m++) {
		ImOpened = false; //no image opened yet
       	if (endsWith(listR[m], ".tif") && indexOf(listR[m], "_X")>-1){
       		path = DirR+listR[m];
       		open(path);
			ImOpened = true;
			name = listR[m];
       	}

		if (endsWith(listR[m], "/") && indexOf(listR[m], "_X")>-1){ //if it's a sub-folder, check whether it contains a single image
			subdir = DirR + listR[m];
			sublist = getFileList(subdir);
			ImCounter = 0;
			name = substring(listR[m], 0, lengthOf(listR[m])-1);
			for (k = 0; k < sublist.length; k++) {
				if (endsWith(sublist[k], ".tif")){
					ImCounter++;
					subpath = subdir + sublist[k];
				}
				if (endsWith(sublist[k], "/")){ //if it's a sub-folder, check whether it contains asingle image
					subsubdir = subdir + sublist[k];
					subsublist = getFileList(subsubdir);
					for (p = 0; p < subsublist.length; p++) {// one more level of sub-folders
						if (endsWith(subsublist[p], ".tif")){
							ImCounter++;
							subpath = subsubdir + subsublist[p];
						}
					}
				}
			}
			if (ImCounter == 1) {
				path = subpath;
				open(path);
				ImOpened = true;
			}	
		}
       		
       	if (ImOpened){ //do processing only if an image has been opened
       		point++; //update counter of processed pixels
       		Orig = getImageID();   
       		run("Select None");
       		run("Duplicate...", " ");    		
       		Spect = getImageID();
       		run("32-bit");
       		run("Subtract...", "value="+BckgR);
       		selectImage(Orig);
       		saveAs("Tif", path);
       		close();
       		selectImage(Spect);

       		//despike
			Diff1 = diffImage(Spect);
			Diff2 = diffImage(Diff1);
			getDimensions(W, H, dummy, dummy, dummy);
			run("Select None");
		
			//search 2nd differential image for spikes
			for (k=0; k<2*SpikeWidth-2; k++) {
				Val[k]=getPixel(k, 0);
			}

			for (i=SpikeWidth-1; i<W-(SpikeWidth-1); i++) {
				SFlag1 = false;
				SFlag2 = false;
				SFlag3 = false;
				Val[2*SpikeWidth-2] = getPixel(i+SpikeWidth-1, 0);
				if (Val[SpikeWidth-1] < SpikeThreshold) {
					SFlag1 = true;
					posSp = i+1;
					for (k=0; k<SpikeWidth-1; k++) {
						if (Val[k] > SpikeThreshold2){
							SFlag2 = true;
							loB = i-(SpikeWidth-2)+k;
					}
						}
					for (k=SpikeWidth; k<2*SpikeWidth-1; k++) {
						if (Val[k] > SpikeThreshold2){
							SFlag3 = true;
							hiB = i+2+k-SpikeWidth;
						}
					}
				}
						
				if (SFlag1 && SFlag2 && SFlag3) {
					selectImage(Spect);
					LoVal = getPixel(loB, 0);
					HiVal = getPixel(hiB, 0);
					dist = hiB - loB;
					Grad = (HiVal - LoVal)/dist;
					for (j=1; j<dist; j++) {
						setPixel(loB + j, 0, LoVal + Grad*j);
					}
				}
				
				selectImage(Diff2);
				for (k=0; k<2*SpikeWidth-2; k++) {
					Val[k]=Val[k+1];
				}
			}
		
			selectImage(Diff1);
			close();
			selectImage(Diff2);
			close();
			selectImage(Spect);

			//subtract baseline
			if (baseline) {
				pc0 = 0;
				
				for	(j = 0; j < InitEnd; j++) {
					BaseX0[pc0] = j;
					if (ignoreInit) BaseY0[pc0] = getPixel(InitEnd, 0);
					else BaseY0[pc0] = getPixel(j, 0);
					pc0++;
				}

				for	(j = SilentStart; j < SilentDiv; j++) {
					BaseX0[pc0] = j;
					BaseY0[pc0] = getPixel(j, 0);
					pc0++;
				}
				
				pc1 = 0;

				for	(j = SilentStart; j < SilentEnd; j++) {
					BaseX1[pc1] = j;
					BaseY1[pc1] = getPixel(j, 0);
					pc1++;
				}
				for	(j = Water1Start; j < WaterDiv; j++) {
					BaseX1[pc1] = j;
					BaseY1[pc1] = getPixel(j, 0);
					pc1++;
				}

				TestMin = -1000;
				SegLength = round((SilentStart - InitEnd)/SegNum);
				for (s = 0; s < SegNum; s++) {
					for	(k = 0; k < Points; k++) {
						Min[k] = 1000;
						for	(j = InitEnd+s*SegLength; j < InitEnd+(s+1)*SegLength; j++) {
							val = getPixel(j, 0);
							if ((val < Min[k])&&(val>TestMin)) {
								Min[k] = val;
								BaseX1[pc1] = j;
								BaseY1[pc1] = Min[k];
								BaseX0[pc0] = j;
								BaseY0[pc0] = Min[k];
							}
						}
						pc0++;
						pc1++;
						TestMin = Min[k];
					}
				}

				pc2 = 0;
				for	(j = SilentDiv; j < SilentEnd; j++) {
					BaseX2[pc2] = j;
					BaseY2[pc2] = getPixel(j, 0);
					pc2++;
				}
				for	(j = Water1Start; j < Water1End; j++) {
					BaseX2[pc2] = j;
					BaseY2[pc2] = getPixel(j, 0);
					pc2++;
				}

				pc3 = 0;
				for	(j = Water2Start; j < Water2End; j++) {
					BaseX3[pc3] = j;
					BaseY3[pc3] = getPixel(j, 0);
					pc3++;
				}


				for (i = 0; i < Water2End; i++) {
					Baseline[i] = 0;
					Baseline0[i] = 0;
					Baseline1[i] = 0;
					Baseline2[i] = 0;
					Baseline3[i] = 0;
				}

				Fit.doFit(BCurveN, BaseX0, BaseY0);

				for (i = 0; i < SilentStart; i++) {
					for (j = 0; j < BCurve+1; j++) {
						Baseline0[i] = Baseline0[i] + Fit.p(j) * pow(i,j);
					}
				}
		
				Fit.doFit(BCurveN, BaseX1, BaseY1);

	
				for (i = InitEnd; i < WaterDiv; i++) {
					for (j = 0; j < BCurve+1; j++) {
						Baseline1[i] = Baseline1[i] + Fit.p(j) * pow(i,j);
					}
				}

				Fit.doFit(BCurveN, BaseX2, BaseY2);

				for (i = SilentDiv; i < Water1End; i++) {
					for (j = 0; j < BCurve+1; j++) {
						Baseline2[i] = Baseline2[i] + Fit.p(j) * pow(i,j);
					}
				}

				Fit.doFit(BCurveN, BaseX3, BaseY3);

				for (i = Water2Start; i < Water2End; i++) {
					for (j = 0; j < BCurve+1; j++) {
						Baseline3[i] = Baseline3[i] + Fit.p(j) * pow(i,j);
					}
				}


				for (i = 0; i < InitEnd; i++) {
					if (ignoreInit) {
						Baseline[i] = Baseline0[i];
						val = getPixel(InitEnd,0) - Baseline[i];
						setPixel(i, 0, val);
					} else {
						Baseline[i] = Baseline0[i];
						val = getPixel(i, 0) - Baseline[i];
						setPixel(i, 0, val);
					}
				}

				for (i = InitEnd; i < SilentStart; i++) {
					f = (i-InitEnd)/DivDist0;
					Baseline[i] = f*Baseline1[i] + (1-f)*Baseline0[i];
					val = getPixel(i, 0) - Baseline[i];
					setPixel(i, 0, val);
				}

				for (i = SilentStart; i < Water1Start; i++) {
					Baseline[i] = Baseline1[i];
					val = getPixel(i, 0) - Baseline[i];
					setPixel(i, 0, val);
				}

				for (i = Water1Start; i < WaterDiv; i++) {
					f = (i-Water1Start)/DivDist;
					Baseline[i] = f*Baseline2[i] + (1-f)*Baseline1[i];
					val = getPixel(i, 0) - Baseline[i];
					setPixel(i, 0, val);
				}

				for (i = WaterDiv; i < Water2Start; i++) {
					Baseline[i] = Baseline2[i];
					val = getPixel(i, 0) - Baseline[i];
					setPixel(i, 0, val);
				}

				for (i = Water2Start; i < Water1End; i++) {
					f = (i-Water2Start)/DivDistW;
					Baseline[i] = f*Baseline3[i] + (1-f)*Baseline2[i];
					val = getPixel(i, 0) - Baseline[i];
					setPixel(i, 0, val);
				}

				for (i = Water1End; i < Water2End; i++) {
					Baseline[i] = Baseline3[i];
					val = getPixel(i, 0) - Baseline[i];
					setPixel(i, 0, val);
				}

			}

			//get pixel coordinates
			XInd = indexOf(listR[m], "X");
			YInd = indexOf(listR[m], "Y");
			Xs = substring(listR[m], XInd + 1, XInd + 4);
			X = parseInt(Xs);
			Ys = substring(listR[m], YInd + 1, YInd + 4);
			Y = parseInt(Ys);

			//Integrate the values for all channels
			selectImage(Spect);

			for (n = 0; n < ChanN; n++) {
				makeRectangle(ChanStart[n], 0, ChanEnd[n]-ChanStart[n], 1);
				getStatistics(area, PeakInt);
				run("Select None");

				selectImage(RamanIm);
				if (ChanN > 1) Stack.setChannel(n+1);
				setPixel(X, Y, PeakInt);
				
				selectImage(Spect);
			}

			close();

			if(Brillouin) {
				if (point < MB) { 
					selectImage(BSpect);
					Stack.setFrame(point+1);
					
		       		//fit and subtract baseline
					for (i = 0; i < ROIw; i++) {
						BBaseline[i] = 0;
						BBaseline1[i] = 0;
						BBaseline2[i] = 0;
					}
		       		
		       		pc1 = 0;
				
					for	(j = 0; j < Binit; j++) {
						BBaseX1[pc1] = j;
						BBaseY1[pc1] = getPixel(j, 0);
						pc1++;
					}
						
					pc2 = 0;
	
					for	(j = 1; j < Binit+1; j++) {
						BBaseX2[pc2] = ROIw-j;
						BBaseY2[pc2] = getPixel(ROIw-j, 0);
						pc2++;
					}
	
					TestMin = -1000;
					for	(k = 0; k < Bpoints; k++) {
						Min[k] = 1000;
						for	(j = Binit; j < ROIw/2+1; j++) {
							val = getPixel(j, 0);
							if ((val < Min[k])&&(val>=TestMin)) {
								Min[k] = val;
								BBaseX1[pc1] = j;
								BBaseY1[pc1] = Min[k];
								BBaseX2[pc2] = j;
								BBaseY2[pc2] = Min[k];
							}
						}
						pc2++;
						pc1++;
						TestMin = Min[k];
					}

					TestMin = -1000;
					for	(k = 0; k < Bpoints; k++) {
						Min[k] = 1000;
						for	(j = ROIw/2; j < ROIw - Binit; j++) {
							val = getPixel(j, 0);
							if ((val < Min[k])&&(val>TestMin)) {
								Min[k] = val;
								BBaseX1[pc1] = j;
								BBaseY1[pc1] = Min[k];
								BBaseX2[pc2] = j;
								BBaseY2[pc2] = Min[k];
							}
						}
						pc2++;
						pc1++;
						TestMin = Min[k];
					}

					TestMin = -1000;
					for	(k = 0; k < Bpoints; k++) {
						Min[k] = 1000;
						for	(j = ROIw/2; j > Binit; j--) {
							val = getPixel(j, 0);
							if ((val < Min[k])&&(val>TestMin)) {
								Min[k] = val;
								BBaseX1[pc1] = j;
								BBaseY1[pc1] = Min[k];
								BBaseX2[pc2] = j;
								BBaseY2[pc2] = Min[k];
							}
						}
						pc2++;
						pc1++;
						TestMin = Min[k];
					}

					TestMin = -1000;
					for	(k = 0; k < Bpoints; k++) {
						Min[k] = 1000;
						for	(j = ROIw - Binit; j > ROIw/2; j--) {
							val = getPixel(j, 0);
							if ((val < Min[k])&&(val>TestMin)) {
								Min[k] = val;
								BBaseX1[pc1] = j;
								BBaseY1[pc1] = Min[k];
								BBaseX2[pc2] = j;
								BBaseY2[pc2] = Min[k];
							}
						}
						pc2++;
						pc1++;
						TestMin = Min[k];
					}

					Fit.doFit(BBCurveN, BBaseX1, BBaseY1);
					Plot.create("Title", "X-axis Label", "Y-axis Label", BBaseX1, BBaseY1);
					Plot.add("circle", BBaseX1, BBaseY1);
	
					for (i = 0; i < ROIw; i++) {
						for (j = 0; j < BBCurve+1; j++) {
							BBaseline1[i] = BBaseline1[i] + Fit.p(j) * pow(i,j);
						}
					}
	
					Fit.doFit(BBCurveN, BBaseX2, BBaseY2);
					Plot.add("square", BBaseX2, BBaseY2);
	
					for (i = 0; i < ROIw; i++) {
						for (j = 0; j < BBCurve+1; j++) {
							BBaseline2[i] = BBaseline2[i] + Fit.p(j) * pow(i,j);
						}
					}

					for (i = 0; i < ROIw/2-Binit; i++) {
						BBaseline[i] = BBaseline1[i];
						val = getPixel(i, 0) - BBaseline[i];
						setPixel(i, 0, val);
					}
	
					for (i = ROIw/2-Binit; i < ROIw/2+Binit; i++) {
						f = (i-ROIw/2+Binit)/(2*Binit);
						BBaseline[i] = f*BBaseline2[i] + (1-f)*BBaseline1[i];
						val = getPixel(i, 0) - BBaseline[i];
						setPixel(i, 0, val);
					}

					for (i = ROIw/2+Binit; i < ROIw; i++) {
						BBaseline[i] = BBaseline2[i];
						val = getPixel(i, 0) - BBaseline[i];
						setPixel(i, 0, val);
					}

					selectImage(BaselineIm);
					setSlice(point+1);
					for (i = 0; i < ROIw; i++) {
						setPixel(i, 0, BBaseline[i]);
					}
					selectImage(BSpect);
		       		
					if (maxSearch) { //search for Brillouin peaks
						run("Clear Results");
						run("Find Maxima...", "prominence="+PeakProm+" output=List");
						//loop through the peaks and convert pixel position to B. shift. At the same time check whether peaks come in pairs and discard unpaired peaks
						Shifts = newArray(nResults); //array to store shifts
						Weights = newArray(nResults); //array to store weights associated with the shifts - based on aeas under the peaks
						Paired = newArray(nResults); //array to mark paired peaks
						for (ii = 0; ii < nResults; ii++)  {
							Paired[ii] = false;
						}
						nShifts = 0;
						WeightSum = 0;
						Shift = 0;
						for (Ind1 = 0; Ind1 < nResults-1; Ind1++)  {
							S1 = getResult("X", Ind1);
							if (S1>0 && S1<ROIw && !Paired[Ind1]) { //exclude maxima on the edges and peaks that have been paired already
								s1 = PixToFreq(S1);
								//print("1-"+s1);
								diff = FSR;
								for (Ind2 = Ind1+1; Ind2 < nResults; Ind2++) { //look for a paired peak
									S2 = getResult("X", Ind2);
									s2 = PixToFreq(S2);
									//print("2-"+s2);
									difft = abs(FSR/2 - (s1+s2)/2); //how far are the peaks from being symmetrical around FSR centre
			 						if (difft < diff)  { //we found a better match
			 							diff = difft;
			 							//print(diff);
			 							pairS = S2; //we remember the position
			 							PairInd = Ind2;
			 						}
								}
								if (diff < diffTol) { //if the found difference is within tolerance
									Shifts[nShifts] = (FSR-abs(s1-PixToFreq(pairS)))/2;
									//print(Shifts[nShifts]);
									makeRectangle(maxOf(0,S1-PeakW), 0, minOf(S1+PeakW,ROIw)-maxOf(0,S1-PeakW), 1);
									getStatistics(dummy, Int1);
									makeRectangle(maxOf(0,S2-PeakW), 0, minOf(S2+PeakW,ROIw)-maxOf(0,S2-PeakW), 1);
									getStatistics(dummy, Int2);
									Weights[nShifts] = (Int1+Int2)/2;
									WeightSum = WeightSum + Weights[nShifts];
									Shift = Shift + Shifts[nShifts]*Weights[nShifts];
									Paired[PairInd] = true;
									nShifts++; //we found  a pair of peaks
								}
							}
						}
					} else {
						WeightSum = 0;
						Shift = 0;

						//symmetricize
						for (i = 0; i < ROIw/2; i++) {
							diff = getPixel(i, 0) - getPixel(ROIw-1-i, 0);
							weight = getPixel(i, 0) + getPixel(ROIw-1-i, 0) - abs(diff);
							shift = PixToFreq(i); 
							WeightSum = WeightSum + weight;
							Shift = Shift + shift*weight;
						}
					}
	
					Shift = round(Shift/WeightSum * Brescale); //we calculate a weighted average shift and rescale it for easier visibility
					selectImage(BrIm);
					if (meander){
						yc = floor (point/(Xmax+1));
						xc = point - yc*(Xmax+1);
						if((yc/2 - floor(yc/2)) != 0) xc = Xmax - xc; //meander scan lines first
						setPixel(xc, yc, Shift);
						//print(xc +" "+yc);
					} else	setPixel(X, Y, Shift);
					//print("pixel:"+X+","+Y+"shift:"+Shift);
				}
			}
       	}
       	
		showProgress(m+1, MR+1);
       	
	}

	//write settings to Log and save as text
	print(" ");
	print("PixSizeX = " + PixSizeX +" //pixel size in um");
	print("PixSizeY = " + PixSizeY +" //pixel size in um");
	print(" ");
	print("Raman channels defnitions (in /cm):");
	print("ChanN =" + ChanN +" //number of Raman channels");
	for (n = 0; n < ChanN; n++) {
		print("Chan " + (n+1) + " start = "+ Chanstart[Chans[n]]);
		print("Chan " + (n+1) + " end = "+ Chanend[Chans[n]]);
	}

	print(" ");
	print("spike removal parameters:");
	print("SpikeWidth = "+ SpikeWidth +" //maximum spike width in pixels, 3 or 5 recommended");
	print("SpikeThreshold = " + SpikeThreshold +" //Threshold in 2nd differential image to identify spikes");
	print("SpikeThreshold2 = " + SpikeThreshold2 +" //Threshold of neighbouring pixel in 2nd differential image to identify spikes");
	print(" ");
	print("baseline subtraction settings:");	
	print("baseline = " + baseline +"//do baseline subtraction");
	print("SegNum = " + SegNum +" //number of segments within signature region");
	print("Points = " + Points +" //number of baseline points/segment within fingerprint region");
	print("BCurveN = " + BCurveN +" //polynomial degree");
	print("ignoreInit = " + ignoreInit +"//ignore the first initial empty region - outside of spectrum range");
	print("BckgR = " + BckgR +" //Raman camera offset");
	print(" ");
	print("definitions of significant spectral regions:");
	print("Water1Start = " + Water1Start +" //Start for water peak integration 1");
	print("Water2Start = " + Water2Start +" //Start for water peak integration 2");
	print("Water1End = " + Water1End + " //End for water peak integration 1");
	print("Water2End = " + Water2End + " //End for water peak integration 2");
	print("WaterDiv = " + WaterDiv +" //ending point for fitting silent region baseline");

	print("SilentStart = " + SilentStart +" //Start for silent region integration");
	print("SilentEnd = " + SilentEnd +" //End for silent region integration");

	print("InitEnd = " + InitEnd +" //end of initial empty region");

	print(" ");
	print("parameters of x-axis calibration - specific values determined by spectrometer calibration:");
	print("slope = " + slope);   
	print("offset = " + offset);
	print("pixNum = " + pixNum +"  // number of camera pixels");
	print("laser = " + laser +"  //laser wavelength in nm");
	print(" ");
	print("definitions for Brillouin processing:");
	print("Brillouin = " + Brillouin +" //process a simultaneous Brilloouin image"); 
	if (Brillouin){
		print("meander = " + meander +" //meander scan, lines first");
		print("ROIh = " + ROIh +" //ROI height");
		print("ROIw = " + ROIw +" //ROI width");
		print("ROIy = " + ROIy +" //y coordinate of ROI start");
		print("Roff = " + Roff +" //offset of search ROI from main Rayleigh peak/GHz");
		print("R1 = " + R1 +" //absolute pixel position of main Rayleigh peak");
		print("diffTol = " + diffTol +" //tolerance on Brillouin peak position difference");
		print("PeakProm = " + PeakProm +"//Brillouin peak prominance for maxima search");
		print("PeakW = " + PeakW + "//Brillouin peak half-width for peak integration");
		print("FSR = " + FSR +" //Free spectral range in GHz");
		print("//frequency calibration:");
		print("a = " + a);
		print("b = " + b);
	}

	selectWindow("Log");
	saveAs("Text", DirR + "Settings.txt");
	run("Close");

	//format Raman Image
	selectImage(RamanIm);
	Gmin = 255;
	Gmax = 0;
	for (n = 0; n < ChanN; n++) {
		if(ChanN > 1) Stack.setChannel(n+1);
		getStatistics(area, mean, min, max, std, dummy);
		if (min < Gmin) Gmin = min;
		if (max > Gmax) Gmax = max;
	}
	Min = minOf(0, Gmin);
	Max = 1.05*Gmax;
	for (n = 0; n < ChanN; n++) {
		if(ChanN > 1) Stack.setChannel(n+1);
		setMinAndMax(Min, Max);
	}
	run("8-bit");
	for (n = 0; n < ChanN; n++) {
		if(ChanN > 1) Stack.setChannel(n+1);
		run(LUT[Chans[n]]);
	}
	saveAs("TIF", DirR + "RamanIm.tif");

	//format Brillouin Image
	if (Brillouin) {
		selectImage(BSpect);
		//close();
		selectWindow("Results");
		run("Close");
		selectImage(BrIm);
		run(BLUT);
		saveAs("TIF", DirR + "BrillouinIm.tif");
	}
		
    setBatchMode("exit and display");
    
    for (i = 0; i < ZoomNum; i++) {
		run("In [+]");
    }

    selectImage(RamanIm);
	for (i = 0; i < ZoomNum; i++) {
		run("In [+]");
    }           
       	
	//differential image function used for de-spiking
	function diffImage(Im) {
		getDimensions(w, h, dummy, dummy, dummy);
		makeRectangle(0, 0, w-1, h);
		run("Duplicate...", "title=Spect1");
		selectImage(Im);
		makeRectangle(1, 0, w, h);
		run("Duplicate...", "title=Spect2");
		imageCalculator("Subtract create 32-bit", "Spect2","Spect1");
		Diff = getImageID();
		close("Spect1");
		close("Spect2");
		return (Diff);
	}

	//conversion of shifts in /cm to pixels using known calibration
	function ShifToPix (K) {
		Val = (1/(1/laser - K/10000000) - offset)/slope;
		return round(Val);
	}

	//conversion between pixel and frequency in Brillouin spectra
	function PixToFreq (P) {
		Freq = a*pow(P,2) + b*P + Roff;
		return (Freq);
	}

	//conversion between frequency and pixel in Brillouin spectra
	function FreqToPix (F) {
		Pabs = (-b + sqrt(b*b + 4*a*F))/(2*a);
		P = Pabs - PixToFreq(Roff);
		return round(P);
	}

}
