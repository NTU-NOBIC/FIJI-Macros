// Macro to evaluate in real time R^2 of split images during image splitter alignment
// to be run in MicroManager during live acquisition of the split image
// set the live image as active before starting the macro
// in the ROI settings window set the coordinates of the upper left corner of the first ROI, the ROI dimensions and shift to the second ROI 
// (the default values 0 and 256 correspond to horizontal split of 512x512 chip)
// the ROI correlation plot and R^2 value are updated with selected refresh rate
// to stop the macro close the live image
// Radek Machan, IMCF, NOBIC, www.nobic.sg


macro "ImSplitAlign" {
	
	ID = getImageID();
	getDimensions(wx, hy, dummy, dummy, dummy);
	
	Dialog.create("ROI settings");
	LoopRun = true;
	Dialog.addNumber("ROI 1 X start",10);
	Dialog.addNumber("ROI 1 Y start",10);
	Dialog.addNumber("ROI width",400);
	Dialog.addNumber("ROI height",200);
	Dialog.addNumber("X shift",0);
	Dialog.addNumber("Y shift",256);
	Dialog.addNumber("Refresh rate/ms",100);
	Dialog.show();
	LeftX = Dialog.getNumber;
	LeftY = Dialog.getNumber;
	TestWidth = Dialog.getNumber;
	TestHeight = Dialog.getNumber;
	ShiftX = Dialog.getNumber;
	ShiftY = Dialog.getNumber;
	refRate = Dialog.getNumber;
	
	d=TestWidth*TestHeight;
	x=newArray(d);
	y=newArray(d);

	if (LeftX + TestWidth + ShiftX > wx || LeftX + TestWidth > wx || LeftY + TestHeight + ShiftY > hy || LeftY + TestHeight > hy) {
		showMessage("ROI outside of the image");
		LoopRun = false; 
	}

	if (TestWidth > ShiftX && TestHeight > ShiftY) {
		showMessage("ROIs overlap");
		LoopRun = false; 
	}

	while (LoopRun) {
		for(i=0;i<TestHeight;i++) {
			for(j=0; j<TestWidth;j++) {
				p=i*TestWidth+j; 
				x[p]=getPixel(j + LeftX,i + LeftY);
				y[p]=getPixel(j + LeftX + ShiftX,i + LeftY + ShiftY);
			}
		}
		
		Array.getStatistics(x,Xmin,Xmax);
		Array.getStatistics(y,Ymin,Ymax);

		Plot.create("plot","ROI 1","ROI 2");
		Plot.setLimits(Xmin,Xmax,Ymin,Ymax);
		Plot.setColor("red");
		Plot.add("circles",x,y);
		Fit.doFit("Straight Line", x, y);
		Plot.addText("R^2=" + Fit.rSquared, 0, 0);

		Plot.update();
		wait(refRate);
		if (!isOpen(ID) || !isOpen("plot")) LoopRun = false; 
	}
}

