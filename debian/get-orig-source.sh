#!/bin/sh

BASEDIR=`pwd`
PACKAGE=micro-evtd
URL=http://buffalo.nas-central.org/download/Users/lb_worm/micro_evtd/micro_evtd/

path=$(mktemp -t micro-evtd.XXXXXX -d)
pushd $path > /dev/null
echo -n "Downloading source... "
wget --quiet -r -np -nH --cut-dirs=4 --reject index.html* "$URL"
echo "done."

echo -n "Fixing tarball... "
VERSION=`sed -n '/VERSION/ {s/#define VERSION "\(.*\)"/\1/; p}' micro_evtd/version.h`
mv micro_evtd $PACKAGE-$VERSION
pushd $PACKAGE-$VERSION > /dev/null
rm -f micro_evtd Utils/setMAC/setMAC Utils/wol/wol
popd > /dev/null
chmod 0755 $PACKAGE-$VERSION/Install/EventScript \
           $PACKAGE-$VERSION/Install/microapl

tar zcf "$BASEDIR/$PACKAGE"_"$VERSION.orig.tar.gz" "$PACKAGE-$VERSION"
popd $path > /dev/null

rm -rf $path
echo "done."
