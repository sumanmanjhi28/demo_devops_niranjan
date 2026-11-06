#!/bin/bash
# Script to find available Elastic Beanstalk Solution Stacks for Node.js

echo "========================================="
echo "Finding Available Node.js Solution Stacks"
echo "========================================="
echo ""

echo "Fetching latest Node.js solution stacks from AWS..."
echo ""

# Get the latest Node.js solution stacks
STACKS=$(aws elasticbeanstalk list-available-solution-stacks \
  --region us-east-1 \
  --query "SolutionStacks[?contains(@, 'Node.js')]" \
  --output text 2>/dev/null)

if [ -z "$STACKS" ]; then
  echo "❌ Failed to fetch solution stacks. Please check:"
  echo "   1. AWS credentials are configured"
  echo "   2. AWS CLI is installed"
  echo "   3. You have permissions to call elasticbeanstalk:ListAvailableSolutionStacks"
  exit 1
fi

echo "Available Node.js Solution Stacks (Latest 10):"
echo "========================================="
echo ""

# Display top 10 Node.js stacks
aws elasticbeanstalk list-available-solution-stacks \
  --region us-east-1 \
  --query "SolutionStacks[?contains(@, 'Node.js')] | [0:10]" \
  --output table

echo ""
echo "========================================="
echo ""
echo "📋 Most Recent Node.js 20 Stack:"
LATEST_NODE20=$(aws elasticbeanstalk list-available-solution-stacks \
  --region us-east-1 \
  --query "SolutionStacks[?contains(@, 'Node.js 20')] | [0]" \
  --output text)

if [ -n "$LATEST_NODE20" ]; then
  echo "   $LATEST_NODE20"
  echo ""
  echo "To use this in Terraform, update terraform.tfvars:"
  echo ""
  echo "   eb_solution_stack = \"$LATEST_NODE20\""
else
  echo "   No Node.js 20 stack found"
fi

echo ""
echo "📋 Most Recent Node.js 18 Stack:"
LATEST_NODE18=$(aws elasticbeanstalk list-available-solution-stacks \
  --region us-east-1 \
  --query "SolutionStacks[?contains(@, 'Node.js 18')] | [0]" \
  --output text)

if [ -n "$LATEST_NODE18" ]; then
  echo "   $LATEST_NODE18"
  echo ""
  echo "To use this in Terraform, update terraform.tfvars:"
  echo ""
  echo "   eb_solution_stack = \"$LATEST_NODE18\""
else
  echo "   No Node.js 18 stack found"
fi

echo ""
echo "========================================="
echo ""
echo "💡 Tip: Solution stacks are region-specific and updated regularly by AWS"
echo "   Run this script to get the latest available versions"
echo ""
