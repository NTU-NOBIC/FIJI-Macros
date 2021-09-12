//Resaves as TIF individual files a .CZI file obtained as positions array scan in 96 well format (or a part of it) by ZEN software
// by Radek Machan, IMCF, NOBIC, https://www.biocev.eu/en/services/imaging-methods.8, www.nobic.sg 

macro AxioSave96 {

	PosMax = 96;
	ColMax = 12;
	RowMax = 8;
	RowNames = newArray("A","B","C","D","E","F","G","H");

	Dialog.create("Specify format");
	Dialog.addNumber("Rows",8);
	Dialog.addNumber("Collumns",12);
	Dialog.show();

	Dir = getDirectory("Choose Destination"); 
	
	RowNum = Dialog.getNumber; 
	ColNum = Dialog.getNumber;
	PosNum = RowNum * ColNum;

	if ((RowNum>RowMax) || (ColNum > ColMax)) {
		Dialog.create("Error");
		Dialog.addMessage("Maximum number of rows (8) or collumns (12) exceeded");
		Dialog.show();
		NumCheck = 0;
	}

	ImList = getList("image.titles");
	ImNum = ImList.length;
	if (ImNum == PosNum) NumCheck = 1;
	else {
		Dialog.create("Error");
		Dialog.addMessage("Number of open images does not agree with the specified number of positions");
		Dialog.show();
		NumCheck = 0;
	}

	if (NumCheck == 1) {
		HashPos = indexOf(ImList[0], "#");
		FileName = substring(ImList[0],1, HashPos-1);
		for (i=0; i < ImList.length; i++) {
			selectImage(ImList[i]);
			HashPos = indexOf(ImList[i], "#");
			NumStr = substring(ImList[i], HashPos+1);
			Num = parseInt(NumStr);
			RowInd = floor((Num-1)/ColNum);
			ColInd = Num - (RowInd)*ColNum;
			saveAs("Tiff", Dir+FileName+RowNames[RowInd]+ColInd);
			close();
		}
	}
}