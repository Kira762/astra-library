#!/bin/bash
set -e

echo "Installing dependencies in website directory..."
cd website
npm install

echo "Building Next.js app..."
npm run build

echo "Build complete. Output in website/.next"
