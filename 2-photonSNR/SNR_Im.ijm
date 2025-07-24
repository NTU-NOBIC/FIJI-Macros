AverageFrames = 1;

setBatchMode("hide");
getDimensions(width, height, channels, slices, frames);
if (frames > slices) {
	slices = frames;
	run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
}

CIm = newArray(2);
fg = newArray(2);
FG = newArray(2);

if (AverageFrames > 1 && slices > 2) run("Grouped Z Project...", "projection=[Average Intensity] group=" + AverageFrames);
getDimensions(width, height, channels, slices, frames);
NumPairs = slices - 1;

CSNR = 0;
CSNRsq = 0;
Corrig = getImageID();
rename("Average - SNRcorr("+AverageFrames+")");
run("32-bit");
for (n = 0; n < NumPairs; n++) {
	for (i = 0; i < 2; i++) {
		selectImage(Corrig);
		Stack.setSlice(n+1+i);
		getStatistics(area, fg[i], min, max, std, histogram);
		run("Duplicate...", " ");
		CIm[i] = getImageID();
		run("Duplicate...", " ");
		run("Subtract...", "value="+fg[i]);
		run("Square");
		getStatistics(area, FG[i], min, max, std, histogram);
		close();
	}
	imageCalculator("Multiply create 32-bit", CIm[0],CIm[1]);
	getStatistics(area, FxG, min, max, std, histogram);
	Corr = (FxG - fg[0]*fg[1])/sqrt(FG[0]*FG[1]);
	if(Corr < 0) Corr = 0;
	CSNR = CSNR + sqrt(Corr/(1-Corr));
	CSNRsq = CSNRsq + Corr/(1-Corr);
	close();
	for (i = 0; i < 2; i++) {
		selectImage(CIm[i]);
		close();
	}
	showProgress(n+1, NumPairs);	
}

stDev = sqrt((CSNRsq/NumPairs - pow((CSNR/NumPairs),2))*NumPairs/(NumPairs-1));
CSNR = CSNR/NumPairs;
setBatchMode("exit and display");
print("SNRim("+AverageFrames+") = " + CSNR + " +/- " + stDev);

