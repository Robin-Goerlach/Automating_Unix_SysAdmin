#!/bin/sh
# Shared static configuration renderer. Caller validates source and site first.
render_baseline(){
    old=$(cat "$root/etc/hostname"); short=${host%%.*}
    printf '%s\n' "$old" | awk 'NR!=1 || length($0)>63 || $0!~/^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$/ {bad=1} END{exit(bad || NR!=1)}' || fail 'old hostname must be a short name'
    # Preserve unrelated entries, IPv6 and comments. Reject ambiguous local mapping.
    hosts=$(awk -v old="$old" -v fqdn="$host" -v short="$short" '
    {original=$0; comment=""; if(match($0,/#/)) {comment=substr($0,RSTART); $0=substr($0,1,RSTART-1)}
     if($1=="127.0.0.1") for(i=2;i<=NF;i++) if($i=="localhost") local_ok=1
     if($1=="127.0.1.1") {if(++count>1 || NF<2 || NF>3) bad=1; if(NF==2 && $2!=old && $2!=short) bad=1; if(NF==3 && !(($3==old && index($2,old ".")==1) || ($3==short && $2==fqdn))) bad=1; print "127.0.1.1 " fqdn " " short (comment!="" ? " " comment : ""); next}
     for(i=2;i<=NF;i++) if($i==fqdn || $i==short) bad=1; print original}
    END{if(!local_ok || bad) exit 1; if(!count) print "127.0.1.1 " fqdn " " short}
' "$root/etc/hosts") || fail 'ambiguous hosts mapping or missing localhost'
    resolver=$(awk '$1!~/^(nameserver|search|domain)$/ {print}' "$root/etc/resolv.conf") || fail 'resolver read failed'
    if [ -n "$resolver" ]; then resolver=$(printf '%s\n%s' "$resolver" "$expected"); else resolver=$expected; fi
}
