# $Id$

CC = g++
OPTION = -g
INCLUDE = 

OBJECTS = SpSize.o SpFile.o SpPath.o SpTime.o SpTester.o SpLibLoader.o \
          SpUid.o SpGid.o SpImage.o SpImageFormat.o SpImageDim.o \
          SpFsObject.o SpDir.o SpDirMonitor.o SpDirMonitorFam.o \
		  SpImageSequence.o

all: testCode
	cd imageFormats; make all
	LD_LIBRARY_PATH=/usr/local/lib:imageFormats ./testCode
	
clean:
	cd imageFormats; make clean
	rm -fr *.o *.so testCode

testCode: testCode.o $(OBJECTS)
	$(CC) $(OPTION) -rdynamic -o testCode testCode.o $(OBJECTS) -ldl -lfam

testCode.o: testCode.C SpFile.h SpUid.h SpGid.h SpTime.h SpSize.h SpFsObject.h SpDir.h SpFile.h
	$(CC) $(OPTION) -c testCode.C $(INCLUDE)

SpTester.o: SpTester.C SpTester.h
	$(CC) $(OPTION) -c SpTester.C $(INCLUDE)

SpSize.o: SpSize.C SpSize.h
	$(CC) $(OPTION) -c SpSize.C $(INCLUDE)

SpFile.o: SpFile.C SpFile.h SpPath.h SpTime.h SpSize.h SpUid.h SpGid.h
	$(CC) $(OPTION) -c SpFile.C $(INCLUDE)

SpPath.o: SpPath.C SpPath.h
	$(CC) $(OPTION) -c SpPath.C $(INCLUDE)

SpTime.o: SpTime.C SpTime.h
	$(CC) $(OPTION) -c SpTime.C $(INCLUDE)

SpUid.o: SpUid.C SpUid.h
	$(CC) $(OPTION) -c SpUid.C $(INCLUDE)

SpGid.o: SpGid.C SpGid.h
	$(CC) $(OPTION) -c SpGid.C $(INCLUDE)

SpImage.o: SpImage.C SpImage.h SpFile.h
	$(CC) $(OPTION) -c SpImage.C $(INCLUDE)

SpImageFormat.o: SpImageFormat.C SpImageFormat.h SpFile.h
	$(CC) $(OPTION) -c SpImageFormat.C $(INCLUDE)

SpImageSequence.o: SpImageSequence.C SpImageSequence.h
	$(CC) $(OPTION) -c SpImageSequence.C $(INCLUDE)

SpImageDim.o: SpImageDim.C SpImageDim.h
	$(CC) $(OPTION) -c SpImageDim.C $(INCLUDE)

SpFsObject.o: SpFsObject.C SpFsObject.h SpTime.h SpPath.h SpUid.h SpGid.h
	$(CC) $(OPTION) -c SpFsObject.C $(INCLUDE)

SpDir.o: SpDir.C SpDir.h SpFsObject.h
	$(CC) $(OPTION) -c SpDir.C $(INCLUDE)

SpDirMonitor.o: SpDirMonitor.C SpDirMonitor.h
	$(CC) $(OPTION) -c SpDirMonitor.C $(INCLUDE)

SpDirMonitorFam.o: SpDirMonitorFam.C SpDirMonitorFam.h SpDirMonitor.h
	$(CC) $(OPTION) -c SpDirMonitorFam.C $(INCLUDE)

SpLibLoader.o: SpLibLoader.C SpLibLoader.h
	$(CC) $(OPTION) -c SpLibLoader.C $(INCLUDE)

