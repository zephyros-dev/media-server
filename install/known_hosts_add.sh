#!/bin/bash
ssh-keygen -t ed25519
ssh-keyscan -H -t ed25519 localhost >> ~/.ssh/known_hosts