#!/bin/bash

# Example for the Docker Hub V2 API
# Returns all imagas and tags associated with a Docker Hub user account.
# Requires 'jq': https://stedolan.github.io/jq/

# set username and password
UNAME=""
UPASS=""
URL=""

# -------

set -e
echo

# aquire auth token
TOKEN=$(curl -k -s -H "Content-Type: application/json" -X POST -d '{"username": "'${UNAME}'", "password": "'${UPASS}'"}' 'https://${URL}/auth/login | jq -r .auth_token)

# Add user
curl -k -s -H "Authorization: Bearer ${TOKEN}" https://${URL}/api/accounts -X POST -d '{"role":3, "admin":true, "username":"username", "password":"password", "first_name":"name"}' | jq -r '.results|.[]|.name'

curl -k -H "Authorization: Bearer <auth-token>" -X POST https://<ucp-url>/auth/logout
