#!/bin/bash
#
APPLICATIONS_JSON=$("cat" ./applications.json)
APPLICATIONS=$(echo $APPLICATIONS_JSON | jq -r '.applications | keys[]')
NAMESPACE="omni-streaming"

prewarm_image() {
  echo -e "\nPrewarming $APPLICATION_NAME"
  echo -e "--> Image: $IMAGE:$TAG"
  echo -e ""
  "cat" ./prefetch-image.yaml | envsubst | kubectl apply -n ${NAMESPACE} -f -
  kubectl rollout status daemonset -n ${NAMESPACE} image-prepull-${APPLICATION_NAME} && \
    "cat" ./prefetch-image.yaml | envsubst | kubectl delete -n ${NAMESPACE} -f -
  echo -e "\nDone."
}

if [ -z "$1" ]; then
  for APPLICATION_NAME in $APPLICATIONS; do
    IMAGE=$(echo $APPLICATIONS_JSON | jq -r ".applications.\"$APPLICATION_NAME\".image")
    TAG=$(echo $APPLICATIONS_JSON | jq -r ".applications.\"$APPLICATION_NAME\".tag")
    export APPLICATION_NAME=$APPLICATION_NAME
    export APPLICATION_IMAGE=$IMAGE:$TAG

    prewarm_image
  done
else
  APPLICATION_NAME=$( echo "$1" | tr '[:upper:]' '[:lower:]')
  IMAGE=$(echo $APPLICATIONS_JSON | jq -r ".applications.\"$1\".image")
  TAG=$(echo $APPLICATIONS_JSON | jq -r ".applications.\"$1\".tag")
  export APPLICATION_NAME=$APPLICATION_NAME
  export APPLICATION_IMAGE=$IMAGE:$TAG

  prewarm_image
fi
