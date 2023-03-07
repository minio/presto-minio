#!/bin/sh

set -a

NODEDATADIR_SET=`grep node.data-dir $PRESTO_HOME/etc/node.properties`
if [ -z "${NODEDATADIR_SET}" ]; then
    echo "\nnode.data-dir=${PRESTO_HOME}/data" >> ${PRESTO_HOME}/etc/node.properties
else
    echo "node data set"
fi

$PRESTO_HOME/bin/launcher run