#!/bin/sh

# . ./.env && sh ./bin/slack_notification.sh "${ALERT_WEBHOOK}" '#agency-dev' ":lightning_cloud: There's an issue" "Message about that issue!"

url="${1}"
channel="$2"
subject="$3"
message="$4"

username='Pigeon'
emoji=':bird:'

# Build our JSON payload and send it as a POST request to the Slack incoming web-hook URL
payload="payload={\"channel\": \"${channel}\", \"username\": \"${username}\", \"text\": \"*${subject}:* ${message}\", \"icon_emoji\": \"${emoji}\", \"link_names\": 1}"
curl -m 5 --data-urlencode "${payload}" "${url}" -A 'Alert'
