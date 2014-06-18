#!/bin/bash

PROGRAM=$0

usage() {
  echo "
  Usage:
    $PROGRAM
       --project <GCE Project>
       --zone gcutil-zone
       --node-name <name-prefix>    # hostname prefix for cluster nodes 
      [--deletepd <true|false>]     # default false
   "
}

while [ $# -gt 0 ]
do
  case $1 in
  --project)      project=$2  ;;
  --zone)         zone=$2  ;;
  --node-name)    nodeName=$2  ;;
  --deletepd)     deletepd=$2  ;;
  *)
     echo "****" Bad argument:  $1
     usage
     exit  ;;
  esac
  shift 2
done

project=${project:-"creativedata-clustertest"}
nodeName=${nodeName:-"mapr"}
zone=${zone:-"us-central1-a"}
deletepd=${deletepd:-false}
list_cluster_nodes_disks() {
	clstr=$1

	cluster_nodes=""
	pdisks=""

	disks=$(gcutil listdisks --project=$project --zone=$zone \
		--format=names --filter="name eq .*-pdisk-[1-9]")

	for n in $(gcutil listinstances --project=$project \
		--format=names --filter="name eq .*${clstr}[0-9]+" | sort) 
	do
		[ -z $zone ] && zone=${n%%/*}
		nodename=`basename $n`

		cluster_nodes="${cluster_nodes} $nodename"

		for d in $disks
		do
			diskname=`basename $d`
			[ ${diskname#${nodename}} = ${diskname} ] && continue
			pdisks="${pdisks} $diskname"
	 	done

 	done

	export cluster_nodes
	export pdisks
}

list_cluster_nodes_disks $nodeName

echo "CHECK: -----"
echo "  project      $project"
echo "  zone         $zone"
echo "  nodes       $cluster_nodes"
echo "  pdisks      $pdisks"
echo "  deletepd     $deletepd"
echo "-----"
echo ""
echo "Proceed {y/N} ? "
read YoN
if [ -z "${YoN:-}"  -o  -n "${YoN%[yY]*}" ] ; then
	exit 1
fi

# delete boot ?
if [ $deletepd == "true" ] ; then
	deletepdopt="--delete_boot_pd"
else
	deletepdopt="--nodelete_boot_pd"
fi

echo "Saving instances names..."
echo $cluster_nodes > .deleted_instances

echo "Deleting instances ${cluster_nodes}..."

# Delete instances
gcutil deleteinstance \
	--project=$project \
	--zone=$zone \
	$deletepdopt \
	--force \
	$cluster_nodes

# Delete disk if needed
if [ $deletepd == "true" ] ; then
	gcutil deletedisk --force $pdisks
fi