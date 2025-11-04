#!/usr/bin/env bash


pnpm install
( cd ui && pnpm build:production )

output_dir=ram-usage-analyzer/site-dist

rm -rf $output_dir 
cp -r ui/dist $output_dir 
