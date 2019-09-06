#!/bin/bash

SERVICE_ACCOUNT_NAME=$1
SERVICE_ACCOUNT_DEST=$2

if [ ! -n "$SERVICE_ACCOUNT_NAME" ]; then
	echo "Requires: SERVICE_ACCOUNT_NAME"
	exit 1
fi

if [ ! -n "$SERVICE_ACCOUNT_NAME" ]; then
	echo "Requires: SERVICE_ACCOUNT_NAME"
	exit 1
fi

mkdir -p $(dirname $SERVICE_ACCOUNT_DEST)
PROJECT=$(gcloud info --format='value(config.project)')

SA_EMAIL=$(gcloud iam service-accounts list \
    --filter="displayName:$SERVICE_ACCOUNT_NAME" \
    --format='value(email)')

if [ -n "$SA_EMAIL" ]; then
	echo "$SERVICE_ACCOUNT_NAME already in use"
	exit 1
fi

gcloud iam service-accounts create \
  $SERVICE_ACCOUNT_NAME \
  --display-name $SERVICE_ACCOUNT_NAME

sleep 5

SA_EMAIL=$(gcloud iam service-accounts list \
    --filter="displayName:$SERVICE_ACCOUNT_NAME" \
    --format='value(email)')

if [ ! -n "$SA_EMAIL" ]; then
	echo "$SERVICE_ACCOUNT_NAME was not created"
	exit 1
fi

gcloud projects add-iam-policy-binding $PROJECT \
    --role roles/storage.admin --member serviceAccount:$SA_EMAIL

gcloud iam service-accounts keys create $SERVICE_ACCOUNT_DEST \
    --iam-account $SA_EMAIL
