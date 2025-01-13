#!/bin/bash
kubectl create secret generic azure-config-file --namespace "default" --from-file ./azure.json
