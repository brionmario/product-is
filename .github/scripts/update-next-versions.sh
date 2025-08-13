#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# GitHub token - set as environment variable or replace with your token
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
POM_FILE="pom.xml"

if [[ -z "$GITHUB_TOKEN" ]]; then
    echo -e "${RED}Error: GITHUB_TOKEN environment variable is not set${NC}"
    echo "Please set your GitHub token: export GITHUB_TOKEN=your_token_here"
    exit 1
fi

if [[ ! -f "$POM_FILE" ]]; then
    echo -e "${RED}Error: pom.xml not found in current directory${NC}"
    exit 1
fi

echo -e "${BLUE}🚀 Starting version updates for next releases...${NC}"
echo ""

# Helper function to get latest next release tag from GitHub
get_latest_next_release() {
    local repo="$1"
    local tag=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$repo/tags" | \
        jq -r '.[] | select(.name | contains("next")) | .name' | \
        head -1)
    
    if [[ -n "$tag" && "$tag" != "null" ]]; then
        # Remove 'v' prefix if it exists
        echo "${tag#v}"
    else
        echo ""
    fi
}

# Helper function to get specific identity-apps package version
get_identity_apps_version() {
    local package="$1"  # e.g., "console", "myaccount", "identity-apps-core"
    local tag=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/wso2/identity-apps/releases" | \
        jq -r --arg pkg "@wso2is/$package" '.[] | select(.tag_name | startswith($pkg + "@")) | select(.tag_name | contains("next")) | .tag_name' | \
        head -1)
    
    if [[ -n "$tag" && "$tag" != "null" ]]; then
        # Extract version from tag like "@wso2is/console@2.69.1-next.0"
        echo "${tag##*@}"
    else
        echo ""
    fi
}

# Helper function to update pom.xml property
update_pom_property() {
    local prop="$1"
    local version="$2"
    
    if [[ -n "$version" ]]; then
        # Create backup
        cp "$POM_FILE" "$POM_FILE.bak"
        
        # Update the property using sed
        sed -i.tmp "s|<$prop>.*</$prop>|<$prop>$version</$prop>|g" "$POM_FILE"
        rm "$POM_FILE.tmp"
        
        echo -e "${GREEN}✅ Updated $prop to $version${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  No next version found for $prop - skipping${NC}"
        return 0
    fi
}

echo -e "${BLUE}📦 Fetching identity-apps GitHub release versions...${NC}"

# 1. identity-apps packages from GitHub releases (special handling)
echo -e "${BLUE}Checking wso2/identity-apps...${NC}"
console_version=$(get_identity_apps_version "console")
myaccount_version=$(get_identity_apps_version "myaccount")
core_version=$(get_identity_apps_version "identity-apps-core")

update_pom_property "identity.apps.console.version" "$console_version"
update_pom_property "identity.apps.myaccount.version" "$myaccount_version"
update_pom_property "identity.apps.core.version" "$core_version"

echo ""
echo -e "${BLUE}📦 Fetching GitHub release versions...${NC}"

# 2. identity-api-server
echo -e "${BLUE}Checking wso2/identity-api-server...${NC}"
api_server_version=$(get_latest_next_release "wso2/identity-api-server")
update_pom_property "identity.server.api.version" "$api_server_version"

# 3. identity-api-user
echo -e "${BLUE}Checking wso2/identity-api-user...${NC}"
api_user_version=$(get_latest_next_release "wso2/identity-api-user")
update_pom_property "identity.user.api.version" "$api_user_version"

# 4. carbon-identity-framework
echo -e "${BLUE}Checking wso2/carbon-identity-framework...${NC}"
framework_version=$(get_latest_next_release "wso2/carbon-identity-framework")
update_pom_property "carbon.identity.framework.version" "$framework_version"

# 5. identity-organization-management-core
echo -e "${BLUE}Checking wso2/identity-organization-management-core...${NC}"
org_mgt_core_version=$(get_latest_next_release "wso2/identity-organization-management-core")
update_pom_property "identity.org.mgt.core.version" "$org_mgt_core_version"

# 6. identity-governance
echo -e "${BLUE}Checking wso2-extensions/identity-governance...${NC}"
governance_version=$(get_latest_next_release "wso2-extensions/identity-governance")
update_pom_property "identity.governance.version" "$governance_version"

# 7. identity-organization-management
echo -e "${BLUE}Checking wso2-extensions/identity-organization-management...${NC}"
org_mgt_version=$(get_latest_next_release "wso2-extensions/identity-organization-management")
update_pom_property "identity.org.mgt.version" "$org_mgt_version"

# 8. carbon-kernel
echo -e "${BLUE}Checking wso2/carbon-kernel...${NC}"
kernel_version=$(get_latest_next_release "wso2/carbon-kernel")
update_pom_property "carbon.kernel.version" "$kernel_version"

# 9. identity-inbound-provisioning-scim2
echo -e "${BLUE}Checking wso2-extensions/identity-inbound-provisioning-scim2...${NC}"
scim2_version=$(get_latest_next_release "wso2-extensions/identity-inbound-provisioning-scim2")
update_pom_property "identity.inbound.provisioning.scim2.version" "$scim2_version"

# 10. identity-inbound-auth-oauth
echo -e "${BLUE}Checking wso2-extensions/identity-inbound-auth-oauth...${NC}"
oauth_version=$(get_latest_next_release "wso2-extensions/identity-inbound-auth-oauth")
update_pom_property "identity.inbound.auth.oauth.version" "$oauth_version"

# 11. identity-webhook-event-handlers
echo -e "${BLUE}Checking wso2-extensions/identity-webhook-event-handlers...${NC}"
webhook_version=$(get_latest_next_release "wso2-extensions/identity-webhook-event-handlers")
update_pom_property "org.wso2.identity.webhook.event.handlers.version" "$webhook_version"

# 12. identity-event-publishers
echo -e "${BLUE}Checking wso2-extensions/identity-event-publishers...${NC}"
publishers_version=$(get_latest_next_release "wso2-extensions/identity-event-publishers")
update_pom_property "org.wso2.identity.event.publishers.version" "$publishers_version"

echo ""
echo -e "${GREEN}🎉 Version update process completed!${NC}"
echo -e "${BLUE}📄 Backup created: $POM_FILE.bak${NC}"

# Show git diff if available
if command -v git &> /dev/null && git rev-parse --git-dir > /dev/null 2>&1; then
    echo ""
    echo -e "${BLUE}📋 Changes made:${NC}"
    git diff --no-index "$POM_FILE.bak" "$POM_FILE" | grep "^[+-]" | grep -E "(identity\.|carbon\.|org\.wso2)" || echo "No changes detected"
fi

echo ""
echo -e "${YELLOW}Note: Please review the changes before committing.${NC}"
