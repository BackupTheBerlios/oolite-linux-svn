#! /bin/bash

cd ..


# Paths relative to .., i.e. Cocoa-deps.
TEMPDIR="temp-download-mozilla"
TARGETDIR="../Cross-platform-deps/mozilla"

URLFILE="../URLs/mozilla.url"
VERSIONFILE="$TARGETDIR/current.url"

TEMPFILE="$TEMPDIR/mozilla.tbz"


DESIREDURL=`head -n 1 $URLFILE`


# Report failure, as an error if there's no existing code but as a warning if there is.
function fail
{
	if [ $LIBRARY_PRESENT -eq 1 ]
	then
		echo "warning: $1, using existing code originating from $CURRENTURL."
		exit 0
	else
		echo "error: $1"
		exit 1
	fi
}


# Determine whether an update is desireable, and whether there's mozilla code in place.
if [ -d $TARGETDIR ]
then
	LIBRARY_PRESENT=1
	if [ -e $VERSIONFILE ]
	then
		CURRENTURL=`head -n 1 $VERSIONFILE`
		if [ $DESIREDURL = $CURRENTURL ]
		then
			echo "libjs is up to date."
			exit 0
		else
			echo "libjs is out of date."
		fi
	else
		echo "current.url not present, assuming libjs is out of date."
		CURRENTURL="disk"
	fi
else
	LIBRARY_PRESENT=0
	echo "libjs not present, initial download needed."
fi


# Clean up temp directory if it's hanging about.
if [ -d $TEMPDIR ]
then
	rm -rf $TEMPDIR
fi


# Create temp directory.
mkdir $TEMPDIR
if [ ! $? ]
then
	echo "error: Could not create temporary directory $TEMPDIR."
	exit 1
fi


# Download mozilla source.
echo "Downloading libjs source from $DESIREDURL... (This is slow. Have some coffee.)"
curl -qgsS -o $TEMPFILE $DESIREDURL
RESULT=$?
if [ ! $RESULT ]
then
	echo "Result is $RESULT"
	fail "could not download $DESIREDURL"
fi


# Expand tarball.
echo "Download complete, expanding archive... (This is also slow. Have a cigar.)"
tar -xkf $TEMPFILE -C $TEMPDIR
if [ ! $? ]
then
	fail "could not expand $TEMPFILE into $TEMPDIR"
fi


# Remove tarball.
rm $TEMPFILE

# Delete existing code.
rm -rf $TARGETDIR

# Create new root mozilla directory.
mkdir $TARGETDIR


# Move new code into place.
mv $TEMPDIR/mozilla-central/js $TARGETDIR/js
if [ ! $? ]
then
	echo "error: could not move expanded libjs source into place."
	exit 1
fi

mv $TEMPDIR/mozilla-central/nsprpub $TARGETDIR/nsprpub
if [ ! $? ]
then
	echo "error: could not move expanded libnspr4 source into place."
	exit 1
fi

# Note version for future reference.
echo $DESIREDURL > $VERSIONFILE

# Remove temp directory.
echo "Cleaning up."
rm -rf $TEMPDIR

echo "Successfully updated libjs."
