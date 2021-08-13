#!/bin/bash
#echo  $(( $1 & 16384 ))

if [ $(( $1 & 1 )) -gt 0 ]
then
    echo "Known Violators"
fi
if [ $(( $1 & 2 )) -gt 0 ]
then
    echo "Blocked Country"
fi
if [ $(( $1 & 4 )) -gt 0 ]
then
    echo "Browser Integrity"
fi
if [ $(( $1 & 8 )) -gt 0 ]
then
    echo "KV UA"
fi
if [ $(( $1 & 16 )) -gt 0 ]
then
    echo "PPM"
fi
if [ $(( $1 & 32 )) -gt 0 ]
then
    echo "KV HPL"
fi
if [ $(( $1 & 64 )) -gt 0 ]
then
    echo "Referrer Block"
fi
if [ $(( $1 & 128 )) -gt 0 ]
then
    echo "SL"
fi
if [ $(( $1 & 256 )) -gt 0 ]
then
    echo "PPS"
fi
if [ $(( $1 & 512 )) -gt 0 ]
then
    echo "Bad UA"
fi
if [ $(( $1 & 1024 )) -gt 0 ]
then
    echo "AUA"
fi
if [ $(( $1 & 2048 )) -gt 0 ]
then
    echo "IP Blacklist"
fi
if [ $(( $1 & 4096 )) -gt 0 ]
then
    echo "JS Not Loaded"
fi
if [ $(( $1 & 8192 )) -gt 0 ]
then
    echo "JS Check Failed"
fi
if [ $(( $1 & 16384 )) -gt 0 ]
then
    echo "Mentat"
fi
if [ $(( $1 & 32768 )) -gt 0 ]
then
    echo "KV AB (e.g. Selenium)"
fi
if [ $(( $1 & 65536 )) -gt 0 ]
then
    echo "Form Spam Submission"
fi
if [ $(( $1 & 131072 )) -gt 0 ]
then
    echo "Unverified Signature (Identifier - token tampering/expired)"
fi
if [ $(( $1 & 262144 )) -gt 0 ]
then
    echo "IP Pinning Failure (Access IP != JS Clear IP)"
fi
if [ $(( $1 & 524288 )) -gt 0 ]
then
    echo "Invalid JS Test Results (beta)"
fi
if [ $(( $1 & 1048576 )) -gt 0 ]
then
    echo "GeoIP Org ACL"
fi
if [ $(( $1 & 2097152 )) -gt 0 ]
then
    echo "KV DC"
fi
if [ $(( $1 & 4194304 )) -gt 0 ]
then
    echo "ACL - UA"
fi
if [ $(( $1 & 8388608 )) -gt 0 ]
then
    echo "ACL - ID"
fi
if [ $(( $1 & 16777216 )) -gt 0 ]
then
    echo "ACL - Header"
fi
if [ $(( $1 & 134217728 )) -gt 0 ]
then
    echo "ACL - Extension"
fi
if [ $(( $1 & 268435456 )) -gt 0 ]
then
    echo "Missing Unique ID"
fi
if [ $(( $1 & 536870912 )) -gt 0 ]
then
    echo "RPM SDK"
fi
if [ $(( $1 & 1073741824 )) -gt 0 ]
then
    echo "RPS SDK"
fi
