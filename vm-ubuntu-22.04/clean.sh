#! /bin/bash

# To reduce disk space used by the virtual machine, delete many build
# files created during execution of root-bootstrap.sh and
# user-bootstrap.sh scripts.

# This script is _not_ automatically run during creation of the VM, so
# that if anything goes wrong during the build, all of the resulting
# files are left behind for examination.

DF1_BEFORE=`df -h .`
DF2_BEFORE=`df -BM .`

# Remove protobuf and grpc sources completely, since they are large
# and easily downloadable.
/bin/rm -fr protobuf grpc

cd behavioral-model
make clean
cd ..

cd p4c
/bin/rm -fr build
cd ..

/bin/rm usr-local-*.txt pip3-list-2b-*.txt

sudo apt autoremove
sudo apt clean

# Zero out unused disk blocks.  Results in significantly smaller VM
# image files.

echo "Writing zeros to unused disk blocks (be patient) ..."
FNAME=`mktemp --tmpdir big-empty-zero-file-XXXXXXXX`
dd if=/dev/zero of=${FNAME} bs=4096k
/bin/rm -f ${FNAME}

echo "Disk usage before running this script:"
echo "$DF1_BEFORE"
echo "$DF2_BEFORE"

echo ""
echo "Disk usage after running this script:"
df -h .
df -BM .
