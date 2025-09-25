#!/bin/sh

# Clear trash on /data/data @Bias_khaliq
for DIR in /data/data/*; do
  if [ -d "${DIR}" ]; then
    rm -rf ${DIR}/cache/*
    rm -rf ${DIR}/no_backup/*
    rm -rf ${DIR}/app_webview/*
    rm -rf ${DIR}/code_cache/*
  fi
done

# Cache cleaner by Taka
find /data/data/*/cache/* -delete &>/dev/null
find /data/data/*/code_cache/* -delete &>/dev/null
find /data/user_de/*/*/cache/* -delete &>/dev/null
find /data/user_de/*/*/code_cache/* -delete &>/dev/null
find /sdcard/Android/data/*/cache/* -delete &>/dev/null