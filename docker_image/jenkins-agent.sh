#!/usr/bin/env bash
set -euo pipefail

echo "========== jenkins-agent.sh starting =========="
echo "Args: $*"
echo "------------------------------------------------"

# Force agents to connect via FQDN (matches TLS cert SAN), even if an IP is passed.
# Override at runtime if needed:  JENKINS_FQDN=jenkins.awsc.leadfusion.com
JENKINS_FQDN="${JENKINS_FQDN:-jenkins.awsc.leadfusion.com}"

echo "Source check:"
echo "  argv[1]=${1:-<none>}"
echo "  argv[2]=${2:-<none>}"
echo "  env  JENKINS_URL='${JENKINS_URL:-<unset>}'"
echo "  env  SLAVE_NODE_NAME='${SLAVE_NODE_NAME:-<unset>}'"
echo "  env  SLAVE_NODE_SECRET='${SLAVE_NODE_SECRET:+<set>}'"
echo "  env  JENKINS_FQDN='${JENKINS_FQDN}'"
echo "------------------------------------------------"

# Support ECS plugin style:
#   -url <JENKINS_URL> <SECRET> <AGENT_NAME>
if [[ "${1:-}" == "-url" && -n "${2:-}" && -n "${3:-}" && -n "${4:-}" ]]; then
  export JENKINS_URL="$2"
  export JENKINS_SECRET="$3"
  export JENKINS_AGENT_NAME="$4"
fi

# Fallback to plugin env vars if present
export JENKINS_AGENT_NAME="${JENKINS_AGENT_NAME:-${SLAVE_NODE_NAME:-}}"
export JENKINS_SECRET="${JENKINS_SECRET:-${SLAVE_NODE_SECRET:-}}"
export JENKINS_URL="${JENKINS_URL:-}"
export JENKINS_AGENT_WORKDIR="${JENKINS_AGENT_WORKDIR:-/workspace}"

# --- Normalize Jenkins URL to FQDN (fixes TLS SAN mismatch if IP is passed) ---
# If empty, set to the expected FQDN.
if [[ -z "${JENKINS_URL}" ]]; then
  JENKINS_URL="https://${JENKINS_FQDN}/"
fi

# Replace the private IP with FQDN if present (common failure mode).
JENKINS_URL="${JENKINS_URL//10.0.1.18/${JENKINS_FQDN}}"

# If someone passed a bare host/IP without scheme, add https://
if [[ -n "${JENKINS_URL}" && ! "${JENKINS_URL}" =~ ^https?:// ]]; then
  JENKINS_URL="https://${JENKINS_URL}"
fi

# Ensure trailing slash consistency
[[ "${JENKINS_URL}" != */ ]] && JENKINS_URL="${JENKINS_URL}/"

export JENKINS_URL
# ---------------------------------------------------------------------------

echo "Key Jenkins-related values resolved to:"
echo "  JENKINS_URL        = '${JENKINS_URL}'"
echo "  JENKINS_SECRET     = '${JENKINS_SECRET:+<set>}'"
echo "  JENKINS_AGENT_NAME = '${JENKINS_AGENT_NAME:-<empty>}'"
echo "  WORKDIR            = '${JENKINS_AGENT_WORKDIR}'"
echo "------------------------------------------------"

if [[ -z "${JENKINS_URL}" || -z "${JENKINS_SECRET}" || -z "${JENKINS_AGENT_NAME}" ]]; then
  echo "ERROR: Missing required Jenkins connection values."
  echo "Dumping env (filtered):"
  env | sort | egrep "^(JENKINS_|SLAVE_)" || true
  sleep 30
  exit 1
fi

mkdir -p /usr/share/jenkins
mkdir -p "${JENKINS_AGENT_WORKDIR}"

# ---- Debug + fail-fast download (fixes "exit 28" mystery) ----
HOST="$(echo "${JENKINS_URL%/}" | sed -E 's#^https?://##')"
HOST="${HOST%%/*}"

echo "DNS resolution for ${HOST}:"
getent hosts "${HOST}" || true
echo "------------------------------------------------"

AGENT_JAR_URL="${JENKINS_URL%/}/jnlpJars/agent.jar"
echo "Downloading agent.jar from: ${AGENT_JAR_URL}"

# Force IPv4 (-4), follow redirects (-L), verbose (-v), fail on HTTP errors (-f),
# and don't hang forever (timeouts).
curl -4 -v -fL --connect-timeout 5 --max-time 20 \
  "${AGENT_JAR_URL}" \
  -o /usr/share/jenkins/agent.jar

echo "Downloaded agent.jar ($(wc -c </usr/share/jenkins/agent.jar) bytes)."
echo "------------------------------------------------"

echo "Starting Jenkins inbound agent (WebSocket preferred)..."
exec java -jar /usr/share/jenkins/agent.jar \
  -url "${JENKINS_URL%/}" \
  -secret "${JENKINS_SECRET}" \
  -name "${JENKINS_AGENT_NAME}" \
  -workDir "${JENKINS_AGENT_WORKDIR}" \
  -webSocket
