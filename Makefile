# $Id$

CC = g++
OPTION = -g
INCLUDE = 

SO_OBJECTS = SpTIFFImage.so SpFITImage.so SpPRMANZImage.so SpSGIImage.so\
		  SpGIFImage.so SpCINEONImage.so SpIFFImage.so SpPRTEXImage.so
		  
OBJECTS = SpSize.o SpFile.o SpPath.o SpTime.o SpTester.o \
          SpUid.o SpGid.o SpImage.o SpImageDim.o SpFsObject.o SpDir.o

all: testCode $(SO_OBJECTS)
	LD_LIBRARY_PATH=. ./testCode
	
clean:
	rm -fr ii_files *.o *.so testCode

testCode: testCode.o $(OBJECTS) SpSGIImage.so
	$(CC) $(OPTION) -rdynamic -o testCode testCode.o $(OBJECTS) -ldl

testCode.o: testCode.C SpFile.h SpUid.h SpGid.h SpTime.h SpSize.h SpFsObject.h
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

SpSGIImage.o: SpSGIImage.C SpSGIImage.h SpImage.h
	$(CC) -fPIC $(OPTION) -c SpSGIImage.C $(INCLUDE)
	
SpTIFFImage.o: SpTIFFImage.C SpTIFFImage.h SpImage.h
	$(CC) -fPIC $(OPTION) -c SpTIFFImage.C $(INCLUDE)

SpIFFImage.o: SpIFFImage.C SpIFFImage.h SpImage.h
	$(CC) -fPIC $(OPTION) -c SpIFFImage.C $(INCLUDE)

SpFITImage.o: SpFITImage.C SpFITImage.h SpImage.h
	$(CC) -fPIC $(OPTION) -c SpFITImage.C $(INCLUDE)

SpPRMANZImage.o: SpPRMANZImage.C SpPRMANZImage.h SpImage.h
	$(CC) -fPIC $(OPTION) -c SpPRMANZImage.C $(INCLUDE)

SpPRTEXImage.o: SpPRTEXImage.C SpPRTEXImage.h SpImage.h
	$(CC) -fPIC $(OPTION) -c SpPRTEXImage.C $(INCLUDE)

SpGIFImage.o: SpGIFImage.C SpGIFImage.h SpImage.h
	$(CC) -fPIC $(OPTION) -c SpGIFImage.C $(INCLUDE)

SpCINEONImage.o: SpCINEONImage.C SpCINEONImage.h SpImage.h
	$(CC) -fPIC $(OPTION) -c SpCINEONImage.C $(INCLUDE)

# Make the shared objects

SpSGIImage.so: SpSGIImage.o
	$(CC) -shared -o SpSGIImage.so SpSGIImage.o
SpTIFFImage.so: SpTIFFImage.o
	$(CC) -shared -o SpTIFFImage.so SpTIFFImage.o
SpIFFImage.so: SpIFFImage.o
	$(CC) -shared -o SpIFFImage.so SpIFFImage.o
SpFITImage.so: SpFITImage.o
	$(CC) -shared -o SpFITImage.so SpFITImage.o
SpPRMANZImage.so: SpPRMANZImage.o
	$(CC) -shared -o SpPRMANZImage.so SpPRMANZImage.o
SpPRTEXImage.so: SpPRTEXImage.o
	$(CC) -shared -o SpPRTEXImage.so SpPRTEXImage.o
SpGIFImage.so: SpGIFImage.o
	$(CC) -shared -o SpGIFImage.so SpGIFImage.o
SpCINEONImage.so: SpCINEONImage.o
	$(CC) -shared -o SpCINEONImage.so SpCINEONImage.o


SpImageDim.o: SpImageDim.C SpImageDim.h
	$(CC) $(OPTION) -c SpImageDim.C $(INCLUDE)

SpFsObject.o: SpFsObject.C SpFsObject.h SpTime.h SpPath.h SpUid.h SpGid.h
	$(CC) $(OPTION) -c SpFsObject.C $(INCLUDE)

SpDir.o: SpDir.C SpDir.h SpFsObject.h
	$(CC) $(OPTION) -c SpDir.C $(INCLUDE)

