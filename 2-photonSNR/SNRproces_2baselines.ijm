LUT = newArray("Green", "Red");
ChanNum = 2;
FramesSlice = 500;
K = newArray(1,1); //scaling factors (for both channels) to convert from ADU to apparent photoelectrons

setBatchMode("hide");
run("32-bit");
getDimensions(width, height, channels, slices, frames);
if(frames > slices) run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
getDimensions(width, height, channels, slices, frames);
name = getTitle();
Dir = getDirectory("image");
Resdir = Dir+"Results"+ File.separator;
if (! File.isDirectory(Resdir)) File.makeDirectory(Resdir);

SlicesN = round(slices/(ChanNum*FramesSlice));

run("Stack to Hyperstack...", "order=xyctz channels="+ChanNum+" frames="+FramesSlice+" slices="+SlicesN+" display=Color");
run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");

orig = getImageID();

run("Z Project...", "projection=[Average Intensity] all");
AVG = getImageID();
rename("Average");
if (ChanNum > 1) {
	Mins = newArray(ChanNum);
	for (i = 0; i < ChanNum; i++) {
		Stack.setChannel(i+1);
		getStatistics(area, mean, min, max, std, histogram);
		Mins[i] = min;
		print("Min = "+ min);
	}
}else{
	getStatistics(area, mean, Min, max, std, histogram);
	print("Min = "+ Min);
}
close();

selectImage(orig);
if (ChanNum > 1) {
	run("Split Channels");
	combString = "";
	for (i = 0; i < ChanNum; i++) {
		selectWindow("C" + i+1 + "-"+name);
		run("Subtract...", "value="+round(Mins[i])+" stack");
		combString = combString + "c"+i+1+"=C" + i+1 + "-"+name + " ";
	}
	run("Merge Channels...", combString+" create");
}else{
	run("Subtract...", "value="+round(Min)+" stack");
}
orig = getImageID();

run("Z Project...", "projection=[Average Intensity] all");
AVG = getImageID();
rename("Average");
if (ChanNum > 1) {
	for (i = 0; i < ChanNum; i++) {
		Stack.setChannel(i+1);
		run("Enhance Contrast", "saturated=0.35");
		run(LUT[i]);
		Property.set("CompositeProjection", "null");
		Stack.setDisplayMode("color");
	}
}

selectImage(orig);
run("Z Project...", "projection=[Standard Deviation] all");
STD = getImageID();
rename("STD");
selectImage(STD);
if (ChanNum > 1) {
	for (i = 0; i < ChanNum; i++) {
		Stack.setChannel(i+1);
		run("Enhance Contrast", "saturated=0.35");
		run(LUT[i]);
		Property.set("CompositeProjection", "null");
		Stack.setDisplayMode("color");
	}
}

run("Duplicate...", "duplicate");
run("Square", "stack");
VAR = getImageID();

imageCalculator("Divide create 32-bit stack", AVG, STD);
SNR = getImageID();
rename("SNR");
selectImage(SNR);
if (ChanNum > 1) {
	for (i = 0; i < ChanNum; i++) {
		Stack.setChannel(i+1);
		run("Enhance Contrast", "saturated=0.35");
		run(LUT[i]);
		Property.set("CompositeProjection", "null");
		Stack.setDisplayMode("color");
	}
}

selectImage(orig);
run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
run(LUT[0]);

if (ChanNum > 1) {
	for (i = 0; i < ChanNum; i++) {
		Stack.setChannel(i+1);
		run("Enhance Contrast", "saturated=0.35");
		run(LUT[i]);
		Property.set("CompositeProjection", "null");
		Stack.setDisplayMode("color");
	}
}

PixNum = width*height*SlicesN;

Mu = newArray(PixNum);
Var = newArray(PixNum);
Std = newArray(PixNum);
Snr = newArray(PixNum);
for (m = 1; m < ChanNum+1; m++) {
	k = 0;
	selectImage(AVG);
	Stack.setChannel(m);
	for (n = 0; n < SlicesN; n++) {
		Stack.setSlice(n+1);
		for (i = 0; i < width; i++) {
			for (j = 0; j < height; j++) {
				Mu[k] = getPixel(i, j)/K[m-1];
				k++;
			}
		}
	}
	
	selectImage(STD);
	k = 0;
	Stack.setChannel(m);
	for (n = 0; n < SlicesN; n++) {
		Stack.setSlice(n+1);
		for (i = 0; i < width; i++) {
			for (j = 0; j < height; j++) {
				Std[k] = getPixel(i, j)/K[m-1];
				if (Std[k] == 0) Std[k] = 0.001;
				k++;
			}
		}
	}
	
	selectImage(VAR);
	k = 0;
	Stack.setChannel(m);
	for (n = 0; n < SlicesN; n++) {
		Stack.setSlice(n+1);
		for (i = 0; i < width; i++) {
			for (j = 0; j < height; j++) {
				Var[k] = getPixel(i, j)/pow(K[m-1],2);
				k++;
			}
		}
	}
	
	for (k = 0; k < PixNum;k++) {
		Snr[k] = Mu[k]/Std[k];
	}
	
	Plot.create("Response Curve", "Mean", "Var");
	Plot.setColor(LUT[m-1]);
	Plot.add("dots", Mu, Var);
	Plot.show();
	saveAs("Tiff", Resdir + name + "_ResponseCurve-" + LUT[m-1] + ".tif");
	
	Plot.create("SNR", "Signal", "SNR");
	Plot.setColor(LUT[m-1]);
	Plot.add("circles", Mu, Snr);
	Plot.show();
	saveAs("Tiff", Resdir + name + "_SNR-" + LUT[m-1] + ".tif");
}
selectImage(VAR);
close();
setBatchMode("exit and display");

