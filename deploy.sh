#!/bin/bash

# Social Wand - Simple Deployment Script
# This script helps you push your changes to GitHub easily

# Navigate to project directory
cd "/Users/trishalirao/Documents/rishi's epic idea/social wand"

# Colors for better output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Social Wand Deployment Script${NC}"
echo ""

# Check if there are any changes
if [[ -z $(git status -s) ]]; then
    echo -e "${YELLOW}⚠️  No changes detected. Your code is already up to date!${NC}"
    exit 0
fi

# Show what files changed
echo -e "${BLUE}📋 Files changed:${NC}"
git status -s
echo ""

# Ask for commit message
echo -e "${BLUE}📝 What did you change? (Enter a brief description):${NC}"
echo -e "${YELLOW}   Example: 'Fixed photo picker bug' or 'Added new feature'${NC}"
read -p "   > " commit_message

# Check if message is empty
if [[ -z "$commit_message" ]]; then
    echo -e "${YELLOW}⚠️  No commit message provided. Using default message.${NC}"
    commit_message="Update: $(date +'%Y-%m-%d %H:%M:%S')"
fi

echo ""
echo -e "${BLUE}📦 Adding all changes...${NC}"
git add .

echo -e "${BLUE}💾 Committing changes...${NC}"
git commit -m "$commit_message"

echo -e "${BLUE}☁️  Pushing to GitHub...${NC}"
git push

# Check if push was successful
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Success! Your changes are now on GitHub!${NC}"
    echo -e "${BLUE}🔗 View your repo: https://github.com/rishikeshmore18/SocialWand${NC}"
else
    echo ""
    echo -e "${YELLOW}❌ Push failed. You may need to authenticate with GitHub.${NC}"
    echo -e "${YELLOW}   If prompted for password, use your Personal Access Token.${NC}"
    exit 1
fi

