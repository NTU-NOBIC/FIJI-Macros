// macro to faciliate visualisation of Raman spectra captured by a camera live
// selects the whole live image in FVB (a row of pixels) and plots profile
// plots intensity vs. wavelength or Raman shift wavenumber (if shift = true)
// the pixel to wavelength/wavenumber calibration is set based on the calibration of NOBIC Raman confocal micro-spectrometer. After changing the calibration-specific values, can be used for other camera-based Raman spectrometerscontrolled by Micro-manager.
// By Radek Machan, NOBIC, www.nobic.sg

macro "RamanSpectLive [Q]" {
	
	slope = 0.1292;   
	offset = 577.35;  // specifi values determined by specttrometer calibration using organic compounds of well-known Raman spectra
	pixNum = 1024;   // number of camera pixels
	refRate = 100;  //plot resfresh rate in ms
	laser = 561;   //laser wavelength in nm
	shift = true;  // display as Raman shift
	label = "wavelenght/nm;

	x=newArray(pixNum);
	y=newArray(pixNum);

	for (i = 0; i < pixNum; i++) {
		x[i] = offset + i*slope;
	}

	if (shift = = true) {
		for (i = 0; i < pixNum; i++) {
			x[i] = (1/laser - 1/x[i])*10000000;
		} 
		label = "Raman shift/cm^-1";
	}

	//Array.getStatistics(x,Xmin,Xmax);
	
	ID = getImageID();
		
	LoopRun = true;
	while (LoopRun) {
		selectImage(ID);
		for (i = 0; i < pixNum; i++) {
			y[i] = getPixel(i,0);
		}
		//Array.getStatistics(y,Ymin,Ymax);

		Plot.create("plot",label,"instensity");
		//Plot.setLimits(Xmin,Xmax,NaN,NaN);
		Plot.setColor("blue");
		Plot.add("line",x,y);

		Plot.update();
		wait(refRate);
		LoopRun = true; 
	}

}
