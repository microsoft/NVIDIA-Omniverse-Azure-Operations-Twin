#!/bin/bash

# Get the list of active sessions
response=$(curl -X 'GET' \
'<Stream_URL>' \
-H 'accept: application/json')

# Use jq to parse the JSON and loop over each item
echo "${response}" | jq -r '.items[] | .id' | while read id; do
  echo "Deleting session with ID: ${id}"
  # Make the DELETE request using the extracted ID
  curl -X 'DELETE' \
  '<Stream_URL>' \
  -H 'accept: */*' \
  -H 'Content-Type: application/json' \
  -d "{\"id\": \"${id}\"}"
  echo # Print a newline for better readability in output
done

