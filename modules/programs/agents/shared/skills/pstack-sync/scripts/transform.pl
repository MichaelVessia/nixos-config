# Mechanical rename from upstream pstack to the vendored vessia tree.
# pstack-sync applies these rules to upstream paths and file contents, for both
# the merge base and the new upstream revision, so they never show up as local
# customizations. Keep the rules deterministic; anything else is a local edit.
s/^name: Poteto Mode$/name: vessia-mode/;
s/^name: Make Bot UI$/name: make-bot-ui/;
s/\bPoteto\b/Vessia/g;
s/\bpoteto\b/vessia/g;
s/\bPstack\b/Vessia/g;
s/\bpstack\b/vessia/g;
