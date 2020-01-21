#Distil threatscore output v0.1
#jtbright 01/20/2020
cls
$status = @{1 = "Known Violators" ; 2 = "Blocked Country" ; 4 = "Browser Integrity" ; 8 = "Known Violator User Agent" ; 16 = "Pages Per Minute" ; 32 = "Known Violator Honeypot Access" ; 64 = "Referrer Block" ; 128 = "Session Length Exceeded" ; 256 = "Pages Per Second" ; 512 = "Bad User Agent" ; 1024 = "Aggregator User Agents" ; 2048 = "IP Blacklist" ; 4096 = "JavaScript Not Loaded" ; 8192 = "JavaScript Check Failed" ; 16384 = "Machine Learning Violation" ; 32768 = "Known Violator Automation Tool (e.g. Selenium)" ; 65536 = "Form Spam Submission" ; 131072 = "Unverified Signature (Identifier - token tampering/expired)" ; 262144 = "IP Pinning Failure (Access IP != JS Clear IP)" ; 524288 = "Invalid JS Test Results" ; 1048576 = "Organization Block" ; 2097152 = "Known Violator Data Center" ; 4194304 = "ACL - User Agent" ; 8388608 = "ACL - Unique Identifier" ; 16777216 = "ACL - Improper Header Name/Value" ; 33554432 = "Invalid Custom Token" ; 67108864 = "Exceeds Maximum CAPTCHA Attempts" ; 134217728 = "ACL - Extension" ; 268435456 = "Missing Unique ID" ; 536870912 = "RPM SDK" ; 1073741824 = "RPS SDK" }
$value = Read-Host -Prompt 'Threatscore'
write-host "`n"
$status.Keys | where { $_ -band $value } | foreach { $status.Get_Item($_) }
write-host "`n"
PAUSE
