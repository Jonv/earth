//  Copyright (C) 2001 Matthew Landauer. All Rights Reserved.
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
// $Id$

#ifndef _testspdirmon_h_
#define _testspdirmon_h_

#include "SpTester.h"
#include "SpPath.h"
#include "SpDirMon.h"

class SpDirMonEvent
{
	public:
		enum SpCode {null, changed, deleted, added};
		enum SpType {file, dir};
		SpDirMonEvent(SpCode c = null, SpType t = file, const SpPath &p = "") : code(c), type(t), path(p) { }
		~SpDirMonEvent() { }
		SpCode getCode() const { return code; }
		SpType getType() const { return type; }
		SpPath getPath() const { return path; }
		bool operator==(const SpDirMonEvent &e) const {
			return ((code == e.code) && (type == e.type) && (path == e.path));
		}
	private:
		SpCode code;
		SpType type;
		SpPath path;
};

class testSpDirMonitor : public SpTester, public SpDirMonObserver
{
private:
	SpDirMonEvent nextEvent;
public:
	testSpDirMonitor();
	void checkNextEvent(string testName, SpDirMon *m, const SpDirMonEvent &event);
	SpDirMonEvent::SpType type(SpFsObject *o);

	void notifyChanged(SpFsObject *o);
	void notifyDeleted(SpFsObject *o);
	void notifyAdded(SpFsObject *o);
	
	void test();
};

#endif