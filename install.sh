#!/bin/sh
# (c) copyleft 2013 Konstantin Artemiev
#
# The script does the following:
#
# * Installing libzeromq-devel onto the system
# * Copying res_kcmsnotify module into Asterisk source tree resource's path (Asterisk source must be already present)
# * Adding libzmq as an external library to Asterisk buildtools' config files 
# * Re-compiles and installs updated asterisk
#
# No warranty. Handle with care.
#

MODULENAME="res_kcmsnotify.c"
CONFIGUREAC="configure.ac"
CONFIGUREACTMP="configure.ac.new"
MENUSELECTDEPS="build_tools/menuselect-deps.in"
MAKEOPTS="makeopts.in"
ASTER_RESOURCEPATH="/res"

if [ "$#" -eq 0 ];then
        echo "Usage: $0 <asterisk source tree path>\n"
	echo "Example $0 /usr/src/asterisk-11.0.1\n"
        else
	echo "**** Warning warning warning! ****"
	echo "**** Do not install libzmq from Ubuntu or Centos repository ****"
	echo "**** you will end up with outdated version that will be successfully linked but won't work ****"
	echo "**** libzmq version 3.0+ is a prereq for the module to function properly *****"
	echo ""
	read -p "Do you wish to install libzmq to your system (y/N)? (libtool required to build libzmq library)" choice
set -e
case "$choice" in 
  y|Y ) 
   	  #sudo apt-get install libzmq-dev
	  git clone https://github.com/zeromq/libzmq.git
	  cd libzmq
	  ./autogen.sh
	  ./configure
	  make && make install
	  cd ..
	  rm -rf zeromq-*
 	rc=$?
        if [ $rc != 0 ] ; then
          echo "failed!\n";
          exit 0
        fi
;;
esac
        SRCDIR=$1
	ASTER_RESOURCEPATH=$SRCDIR$ASTER_RESOURCEPATH
	echo "copying module $MODULENAME into $ASTER_RESOURCEPATH..."
	cp $MODULENAME $ASTER_RESOURCEPATH
 	rc=$?
        if [ $rc != 0 ] ; then
          echo "failed!\n";
          exit 0
        fi
	echo "applying patch to $CONFIGUREAC..."
	sed -n 'H;${x;s/^\n//;s/AST_EXT_LIB_SETUP(.*\n/AST_EXT_LIB_SETUP([ZMQ], [The Intelligent Transport Layer - zeromq], [zmq])\n&/;p;}' $SRCDIR/$CONFIGUREAC | sed -n 'H;${x;s/^\n//;s/AST_EXT_LIB_CHECK(.*\n/AST_EXT_LIB_CHECK([ZMQ], [zmq], [zmq_init], [zmq.h])\n&/;p;}'  >$CONFIGUREACTMP
	rc=$?
	if [ $rc != 0 ] ; then
          echo "failed! AST_EXT_LIB_SETUP entry not found";
    	  exit $rc
	fi
	mv -f $CONFIGUREACTMP "$SRCDIR/$CONFIGUREAC"
        echo "success\n";
        echo "applying patch to $MENUSELECTDEPS..."
	echo "ZMQ=@PBX_ZMQ@" >>$SRCDIR/$MENUSELECTDEPS
	if [ $rc != 0 ] ; then
          echo "failed!";
          exit $rc
        fi
        echo "success\n";
        echo "applying patch to $MAKEOPTS..."
	echo "ZMQ_LIB=@ZMQ_LIB@" >>$SRCDIR/$MAKEOPTS
	if [ $rc != 0 ] ; then
          echo "failed! cannot write to $SRCDIR/$MAKEOPTS";
          exit $rc
        fi
	echo "ZMQ_INCLUDE=@ZMQ_DIR@" >>$SRCDIR/$MAKEOPTS
	if [ $rc != 0 ] ; then
          echo "failed! cannot write to $SRCDIR/$MAKEOPTS";
          exit $rc
        fi
        echo "success\n\n";
        echo "copying configuration file into /etc/asterisk..."
        cp ./res_kcmsnotify.conf /etc/asterisk
        if [ $rc != 0 ] ; then
          echo "failed! cannot copy configuration file\ncheck file system permissions\n\n";
          exit $rc
        fi
        echo "success\n\n";
	cd $SRCDIR
	./bootstrap.sh
	./configure
	make menuselect && make && make install
        fi
