//  Copyright (C) 2001-2003 Matthew Landauer. All Rights Reserved.
//  
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of version 2 of the GNU General Public License as
//  published by the Free Software Foundation.
//
//  This program is distributed in the hope that it would be useful, but
//  WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  Further, any
//  license provided herein, whether implied or otherwise, is limited to
//  this program in accordance with the express provisions of the GNU
//  General Public License.  Patent licenses, if any, provided herein do not
//  apply to combinations of this program with other product or programs, or
//  any other product whatsoever.  This program is distributed without any
//  warranty that the program is delivered free of the rightful claim of any
//  third person by way of infringement or the like.  See the GNU General
//  Public License for more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write the Free Software Foundation, Inc., 59
//  Temple Place - Suite 330, Boston MA 02111-1307, USA.
//
// $Id: ImageSeqMon.cpp,v 1.3 2003/02/03 05:22:54 mlandauer Exp $

#include "ImageSeqMon.h"

namespace Sp {
	
void ImageSeqMon::imageAdded(const CachedImage &image)
{
	// Try adding this image to all of the currently known sequences
	bool added = false;
	for (std::vector<ImageSeq>::iterator i = sequences.begin(); i != sequences.end(); ++i) {
		if (i->addImage(image)) {
			added = true;
			break;
		}
	}
	// If the image was not part of a sequence make a new sequence
	if (!added)
		sequences.push_back(ImageSeq(image));
}

void ImageSeqMon::fileDeleted(const File &file)
{
	// Try deleting this file from all the currently known sequences
	for (std::vector<ImageSeq>::iterator i = sequences.begin(); i != sequences.end(); ++i) {
		if (i->removeImage(file.getPath())) {
			break;
		}
	}
}

std::vector<ImageSeq> ImageSeqMon::getImageSequences() const
{
	return sequences;
}

}
