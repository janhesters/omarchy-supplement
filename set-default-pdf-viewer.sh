#!/bin/bash

echo "[pdf] Setting Xournal++ as default PDF viewer..."
xdg-mime default com.github.xournalpp.xournalpp.desktop application/pdf
echo "[pdf] Done."
