#!/bin/bash

# default-puma-server
# puma-server

###
# init.sh
# Create vm instance Ubuntu 16.04 on GCP
# and deploy puma-server on it
# author: Aleksey Koloskov <vsyscoder@gmail.com>
###

# Initialize variables
source .env

# Create temporary working directory
TEMPWD=$(mktemp -d "${TMPDIR:-/tmp/}$(basename $0).XXXXXXXXXXXX")

echo "*** Check instance '$VM_NAME' exists"
gcloud compute instances describe $VM_NAME > $TEMPWD/vmdescr.yml 2>/dev/null


# If instance not exists, create it
if [ $? -ne 0 ]
then
  # Generate startup script
  echo "*** Generate startup.sh"
  cat install_ruby.sh install_mongodb.sh deploy.sh > $STARTUP_SCRIPT

  # Upload startup script
  echo "*** Create bucket"
  gsutil mb $BUCKET || { echo "ERROR: can't create bucket. Exiting"; exit 100; }
  echo "*** Upload startup script"
  gsutil cp $STARTUP_SCRIPT ${BUCKET}${STARTUP_SCRIPT} || { echo "ERROR: can't upload $STARTUP_SCRIPT to ${BUCKET}${STARTUP_SCRIPT}. Exiting"; exit 100; }

  # Create VM
  echo "*** Create VM"
  gcloud compute instances create $VM_NAME\
    --boot-disk-size=10GB \
    --image-family ubuntu-1604-lts \
    --image-project=ubuntu-os-cloud \
    --machine-type=g1-small \
    --tags "$VM_TAGS" \
    --restart-on-failure \
    --metadata startup-script-url=${BUCKET}${STARTUP_SCRIPT}

  gcloud compute instances describe $VM_NAME > $TEMPWD/vmdescr.yml
fi

# Get VM's external ip
WAN_IP="$(cat $TEMPWD/vmdescr.yml | grep 'natIP: ' | awk '{ print $2; }')"
echo "VM external IP is $WAN_IP"

# Remove temp file and dir
rm $TEMPWD/vmdescr.yml
rm -r $TEMPWD

# Create firewall rule
echo "*** Create firewall rule, if not exists"
gcloud compute firewall-rules describe $FW_RULE &>/dev/null || gcloud compute firewall-rules create $FW_RULE \
  --allow=tcp:$APP_PORT \
  --target-tags="$VM_TAGS"

echo "Completed. Service will be accessible soon at http://$WAN_IP:$APP_PORT"

# TODO: rediness-probe via curl
