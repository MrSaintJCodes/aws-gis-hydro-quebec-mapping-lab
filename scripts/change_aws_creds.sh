#!/usr/bin/env bash
# update-aws-creds.sh — Update ~/.aws/credentials interactively

set -euo pipefail

CREDS_FILE="${AWS_SHARED_CREDENTIALS_FILE:-$HOME/.aws/credentials}"
PROFILE="${1:-default}"

echo "=== AWS Credentials Updater ==="
echo "Profile : $PROFILE"
echo "File    : $CREDS_FILE"
echo ""

# Prompt for credentials (input hidden for secret key)
read -rp "AWS Access Key ID     : " AWS_ACCESS_KEY_ID
read -rsp "AWS Secret Access Key : " AWS_SECRET_ACCESS_KEY
echo ""
read -rp "AWS Session Token (leave blank if none): " AWS_SESSION_TOKEN

# Ensure the .aws directory exists
mkdir -p "$(dirname "$CREDS_FILE")"

# Create the file if it doesn't exist
touch "$CREDS_FILE"

# Check if the profile already exists in the file
if grep -q "^\[$PROFILE\]" "$CREDS_FILE" 2>/dev/null; then
    echo ""
    echo "Profile [$PROFILE] already exists — updating..."

    # Use a temp file for safe in-place editing
    TMP=$(mktemp)

    awk -v profile="[$PROFILE]" \
        -v key="$AWS_ACCESS_KEY_ID" \
        -v secret="$AWS_SECRET_ACCESS_KEY" \
        -v token="$AWS_SESSION_TOKEN" '
        BEGIN { in_profile=0 }
        $0 == profile {
            print $0
            print "aws_access_key_id     = " key
            print "aws_secret_access_key = " secret
            if (token != "") print "aws_session_token     = " token
            in_profile=1
            next
        }
        /^\[/ && $0 != profile { in_profile=0 }
        in_profile && /^aws_(access_key_id|secret_access_key|session_token)/ { next }
        { print }
    ' "$CREDS_FILE" > "$TMP"

    mv "$TMP" "$CREDS_FILE"
else
    echo ""
    echo "Profile [$PROFILE] not found — appending..."

    {
        echo ""
        echo "[$PROFILE]"
        echo "aws_access_key_id     = $AWS_ACCESS_KEY_ID"
        echo "aws_secret_access_key = $AWS_SECRET_ACCESS_KEY"
        [[ -n "$AWS_SESSION_TOKEN" ]] && echo "aws_session_token     = $AWS_SESSION_TOKEN"
    } >> "$CREDS_FILE"
fi

chmod 600 "$CREDS_FILE"
echo "Done. Credentials updated for profile [$PROFILE]."
