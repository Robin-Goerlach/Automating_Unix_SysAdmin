#!/bin/sh
# Shared static policy validation; input is data, never shell code.
valid_hostname() {
    printf '%s\n' "$host" | awk 'NR!=1 {bad=1} {n=split($0,a,"."); if(n<2 || length($0)>253) bad=1; for(i=1;i<=n;i++) if(length(a[i])>63 || a[i]!~/^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$/) bad=1} END{exit(bad || NR!=1)}'
}
render_resolver() {
    [ -f "$site" ] && [ ! -L "$site" ] && [ -r "$site" ] || return 2
    awk -F= '
        /^#/ || /^$/ {next}
        NF!=2 || $1 !~ /^(dns1|dns2|search)$/ || seen[$1]++ {bad=1; next}
        {v[$1]=$2}
        $1=="search" {n=split($2,a,"."); if(n<1 || length($2)>253) bad=1; for(i=1;i<=n;i++) if(length(a[i])>63 || a[i]!~/^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$/) bad=1}
        $1~/^dns/ {n=split($2,a,"."); if(n!=4) bad=1; for(i=1;i<=n;i++) if(a[i]!~/^(0|[1-9][0-9]*)$/ || a[i]>255) bad=1}
        END{if(bad || !seen["dns1"] || !seen["search"]) exit 1; print "nameserver " v["dns1"]; if(seen["dns2"]) print "nameserver " v["dns2"]; print "search " v["search"]}
    ' < "$site"
}
