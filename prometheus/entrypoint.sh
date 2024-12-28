#!/bin/sh

# Display configuration environment variables
echo "PROMETHEUS_TARGET=${PROMETHEUS_TARGET}"
echo "SUI_BRIDGE_MAINNET_TARGET=${SUI_BRIDGE_MAINNET_TARGET}"
echo "SUI_BRIDGE_TESTNET_TARGET=${SUI_BRIDGE_TESTNET_TARGET}"
echo "ALERTMANAGER_TARGET=${ALERTMANAGER_TARGET}"
echo "SUI_VALIDATOR=${SUI_VALIDATOR}"

# Substitute ${SUI_VALIDATOR} in Alert Rules if set
RULES_FILE="/etc/prometheus/rules/sui_bridge_alerts.yml"

if [ -n "$SUI_VALIDATOR" ]; then
  echo "Substituting SUI_VALIDATOR: $SUI_VALIDATOR in alert rules"
  sed -i "s/\${SUI_VALIDATOR}/$SUI_VALIDATOR/g" "$RULES_FILE"
else
  echo "SUI_VALIDATOR is not set. Skipping substitution in rules."
fi

# Generate prometheus.yml configuration
cat <<EOF > /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['${ALERTMANAGER_TARGET:-localhost:9093}']

rule_files:
EOF

# Include Alert Rules Conditionally
if [ -n "${SUI_BRIDGE_MAINNET_TARGET}" ] || [ -n "${SUI_BRIDGE_TESTNET_TARGET}" ]; then
  echo "Including SUI Bridge alert rules"
  cat <<EOF >> /etc/prometheus/prometheus.yml
  - /etc/prometheus/rules/sui_bridge_alerts.yml
EOF
else
  echo "No SUI Bridge targets detected. Skipping alert rules inclusion."
fi

# Add Scrape Configurations
cat <<EOF >> /etc/prometheus/prometheus.yml
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['${PROMETHEUS_TARGET}']
EOF

# Add SUI Bridge Mainnet Scrape Config
if [ -n "${SUI_BRIDGE_MAINNET_TARGET}" ]; then
  echo "Adding scrape config for SUI Bridge Mainnet"
  cat <<EOF >> /etc/prometheus/prometheus.yml
  - job_name: 'sui_bridge_mainnet'
    scheme: 'https'
    static_configs:
      - targets: ['${SUI_BRIDGE_MAINNET_TARGET}']
        labels:
          service: 'sui_bridge'
          environment: 'mainnet'
EOF
fi

# Add SUI Bridge Testnet Scrape Config
if [ -n "${SUI_BRIDGE_TESTNET_TARGET}" ]; then
  echo "Adding scrape config for SUI Bridge Testnet"
  cat <<EOF >> /etc/prometheus/prometheus.yml
  - job_name: 'sui_bridge_testnet'
    scheme: 'https'
    static_configs:
      - targets: ['${SUI_BRIDGE_TESTNET_TARGET}']
        labels:
          service: 'sui_bridge'
          environment: 'testnet'
EOF
fi

# Start Prometheus with the generated configuration
exec prometheus --config.file=/etc/prometheus/prometheus.yml "$@"
