#!/bin/bash

PROGRAM=$0

NODE_NAME_ROOT=node     # used in config file to define nodes for deployment

usage() {
  echo "
  Usage:
    $PROGRAM
       --project <GCE Project>
       --machine-type <machine-type>
       --zone gcutil-zone
       --nodes \"node1 node2 ...\"
   "
}


list_cluster_nodes() {
	cluster_nodes=`cat .deleted_instances`
	export cluster_nodes
}

	# Build up the disk argument CAREFULLY ... the shell
	# addition of extra ' and " characters really confuses the
	# final invocation of gcutil
	#
list_persistent_data_disks() {
	targetNode=$1
		# Compute the disk specifications ... 
		#	N disks of size S from the pdisk parameter

	pdisk_args=""
	
	for d in $(gcutil listdisks --project=$project --zone=$zone \
		--format=names --filter="name eq .*-pdisk-[1-9]") 
	do
		diskname=`basename $d`
		[ ${diskname#${targetNode}} = ${diskname} ] && continue

		pdisk_args=${pdisk_args}' '--disk' '$diskname,mode=READ_WRITE
 	done

	export pdisk_args
}


#
#  MAIN
#
list_cluster_nodes

while [ $# -gt 0 ]
do
  case $1 in
  --cluster)      cluster=$2  ;;
  --project)      project=$2  ;;
  --machine-type) machinetype=$2  ;;
  --nodes)        cluster_nodes=$2  ;;
  --zone)         zone=$2  ;;
  *)
     echo "****" Bad argument:  $1
     usage
     exit  ;;
  esac
  shift 2
done


# Defaults
zone=${zone:-"us-central1-a"}
project=${project:-"creativedata-clustertest"}
machinetype=${machinetype:-"n1-standard-2"}

if [ -z "${cluster_nodes}" ] ; then
	echo "ERROR: no nodes found, please set paramer --nodes"
	exit 1
fi

echo "CHECK: -----"
echo "  project      $project"
echo "  zon          $zone"
echo "  machine type $machinetype"
echo "  nodes        $cluster_nodes"
echo "-----"
echo ""
echo "Proceed {y/N} ? "
read YoN
if [ -z "${YoN:-}"  -o  -n "${YoN%[yY]*}" ] ; then
	exit 1
fi

# Add instances back
for host in $cluster_nodes 
do
	list_persistent_data_disks $host
			# Side effect ... pdisk_args is set 

	gcutil addinstance \
		--project=$project \
		--machine_type=$machinetype \
		--zone=$zone \
		--persistent_boot_disk \
		--disk $host,mode=rw,boot \
		${pdisk_args:-} \
		--wait_until_running \
		--service_account_scopes=storage-full \
    $host &
done

wait

echo ""
echo "$cluster_nodes nodes restarted"
