#!/bin/bash

# SPIN_DECK=https://spinnaker.<doman>
# SPIN_GATE=https://spin-gate.<domain>

# enable google oauth2
hal config security authn oauth2 edit \
  --client-id $CLIENT_ID \
  --client-secret $CLIENT_SECRET \
  --pre-established-redirect-uri $SPIN_GATE/login \
  --provider google

hal config security ui edit \
  --override-base-url $SPIN_DECK
hal config security api edit \
  --override-base-url $SPIN_GATE

hal config security authn oauth2 enable

hal deploy apply
