#!/bin/bash
# read .env.sh
. .env.sh
# read openrc file
. $RC

declare -A URLS=(
[KEYSTONE]=https://keystone.openstack.svc.cluster.local:8443/v3/services
[GLANCE]=https://glance.openstack.svc.cluster.local:8443/v2/images
[NEUTRON]=https://neutron.openstack.svc.cluster.local:8443/v2.0/networks
[CINDER]=https://cinder.openstack.svc.cluster.local:8443/v3/${PROJECT_ID}/volumes
[NOVA]=https://nova.openstack.svc.cluster.local:8443/v2.1/servers
[PLACEMENT]=https://placement.openstack.svc.cluster.local:8443/resource_providers
)
PASSCODE=200
# get OS_TOKEN
OS_TOKEN_DATA=$(cat <<-EOL
{ "auth": {
    "identity": {
      "methods": ["password"],
      "password": {
        "user": {
          "name": "admin",
          "domain": { "id": "default" },
          "password": "${OSPW}"
        }
      }
    },
    "scope": {
      "project": {
        "name": "admin",
        "domain": { "id": "default" }
      }
    }
  }
}
EOL
)
OS_TOKEN=$(curl -iks -H "Content-Type: application/json" \
    -d "${OS_TOKEN_DATA}" \
    "${OS_AUTH_URL}/auth/tokens" | \
    grep x-subject-token |cut -d' ' -f2)

# Get admin project id
PROJECT_ID=$(curl -sk -H "X-Auth-Token: $OS_TOKEN" \
    "${OS_AUTH_URL}/projects" | \
    python3 -c 'import sys, json; data=json.load(sys.stdin)["projects"]; \
        l=[i["id"] for i in data if i["name"] == "admin"]; print(l[0])')

i=1
for i in $(eval echo "{1..$ITERATION}"); do
  echo "# API REQUEST: $i"
  for key in "${!URLS[@]}";do
    scode=$(curl -s -H "X-Auth-Token: $OS_TOKEN" -k -w "%{http_code}" -o /dev/null --connect-timeout ${CONNECT_TIMEOUT} --max-time ${MAX_TIME} ${URLS[$key]})
    ts=$(date +%FT%T)
    [ "$PASSCODE" == "$scode" ] && msg="PASS" || msg="FAIL"
    printf "%10s\t%20s\t%10s\n" "$key" "$ts" "$msg($scode)"
  done
  sleep $SLEEP
  echo
  ((i++))
done
