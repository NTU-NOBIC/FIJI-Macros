Channels = newArray("1","2","3","4");
LUT = newArray("Cyan", "Green", "Red", "Magenta");
Dialog.create("Settings");
Dialog.addChoice("Number of channels", Channels,"2");
Dialog.addNumber("Voxel depth/um", "0.5");
Dialog.addNumber("frames/slice", "1");
Dialog.addCheckbox("Run batch", false);
Dialog.show();
ChanNumS = Dialog.getChoice();
ChanNum = parseInt(ChanNumS);
Zstep = Dialog.getNumber();
FramesSlice = Dialog.getNumber();
Batch = Dialog.getCheckbox();
if (Batch) {
	dir = getDir("input");
	Resdir = dir+"unscrambled"+ File.separator;
	File.makeDirectory(Resdir);
	setBatchMode(true);
	list = getFileList(dir);
    for (j=0; j<list.length; j++) {
    	if (endsWith(list[j], ".tif") || endsWith(list[j], ".tiff")){
    		run("Bio-Formats Importer", "open=["+dir+list[j]+"]");
    		orig = getImageID();
    		name = list[j];
    		nameo = name;
			run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
			getDimensions(width, height, channels, slices, frames);
			if (slices % ChanNum > 0) exit("The number of slices is not divisible by the number of channels");
			if (slices % FramesSlice > 0) exit("The number of slices is not divisible by the number of frames/slice");
			if (ChanNum > 1) {
				run("Deinterleave", "how="+ChanNum);
				if(FramesSlice > 1) {
					name = "AVG_"+nameo;
					for (i = 1; i < ChanNum+1; i++) {
						selectWindow(nameo+" #"+i);
						orig = getImageID();
						run("Grouped Z Project...", "projection=[Average Intensity] group="+FramesSlice);
						aver = getImageID();
						selectImage(orig);
						close();
						selectImage(aver);
					}
				}
				combString = "";
				for (i = 0; i < ChanNum; i++) {
					combString = combString + "c"+i+1+"=["+name+" #"+i+1+"] ";
				}
				 run("Merge Channels...", combString+" create");
				Property.set("CompositeProjection", "null");
				Stack.setDisplayMode("color");
				selectWindow("Composite");
				for (i = 0; i < ChanNum; i++) {
					Stack.setChannel(i+1);
					run("Enhance Contrast", "saturated=0.35");
					run(LUT[i-ChanNum+3+floor(ChanNum/4)]);
				}
			}
			else {
				if(FramesSlice > 1) {
					run("Grouped Z Project...", "projection=[Average Intensity] group="+FramesSlice);
					aver = getImageID();
					selectImage(orig);
					close();
					run("Enhance Contrast", "saturated=0.35");
					selectImage(aver);
				}
			}
			run("Properties...", "voxel_depth="+Zstep);
			saveAs("Tiff", Resdir+list[j]);
			close();
    	}
    }
} else {
	run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
	getDimensions(width, height, channels, slices, frames);
	if (slices % ChanNum > 0) exit("The number of slices is not divisible by the number of channels");
	if (slices % FramesSlice > 0) exit("The number of slices is not divisible by the number of frames/slice");
	name = getTitle();
	nameo = name;
	orig = getImageID();
	if (ChanNum > 1) {
		run("Deinterleave", "how="+ChanNum);
		if(FramesSlice > 1) {
			name = "AVG_"+nameo;
			for (i = 1; i < ChanNum+1; i++) {
				selectWindow(nameo+" #"+i);
				orig = getImageID();
				run("Grouped Z Project...", "projection=[Average Intensity] group="+FramesSlice);
				aver = getImageID();
				selectImage(orig);
				close();
				selectImage(aver);
			}
		}
		combString = "";
		for (i = 0; i < ChanNum; i++) {
			combString = combString + "c"+i+1+"=["+name+" #"+i+1+"] ";
		}
		 run("Merge Channels...", combString+" create");
		Property.set("CompositeProjection", "null");
		Stack.setDisplayMode("color");
		selectWindow("Composite");
		for (i = 0; i < ChanNum; i++) {
			Stack.setChannel(i+1);
			run("Enhance Contrast", "saturated=0.35");
			run(LUT[i-ChanNum+3+floor(ChanNum/4)]);
		}
	}
	else {
		if(FramesSlice > 1) {
			run("Grouped Z Project...", "projection=[Average Intensity] group="+FramesSlice);
			aver = getImageID();
			selectImage(orig);
			close();
			run("Enhance Contrast", "saturated=0.35");
			selectImage(aver);
		}
	}

	run("Properties...", "voxel_depth="+Zstep);
}

