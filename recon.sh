#!/bin/bash

domain=$1

if [ -z "$domain" ]; then
    echo "Usage: $0 <domain>"
    exit 1
fi

echo "[+] Recon & Vulnerability Scan for: $domain"
mkdir -p results/$domain
cd results/$domain

# ENUM SUBDOMAIN

echo "[+] Running Subfinder..."
subfinder -d $domain -all -silent | tee subs.txt

echo "[+] Running Amass Passive..."
amass enum -passive -d $domain -silent | tee -a subs.txt

echo "[+] Removing duplicate subs..."
sort -u subs.txt -o subs.txt


# DNS RESOLUTION

echo "[+] Resolving DNS with dnsx..."
dnsx -l subs.txt -a -resp -silent | tee resolved.txt

# CHECKING LIVE

echo "[+] Checking live hosts with httpx..."
httpx -l resolved.txt -silent -sc -title -ip -o live.txt

# URL PARAM CRAWLING

echo "[+] Crawling URLs using katana..."
katana -u $domain -jsl -ps -kf all -silent | tee crawl.txt

echo "[+] Extracting URLs with parameters..."
grep "=" crawl.txt | sort -u > params_raw.txt

echo "[+] Cleaning URLs..."
uro -i params_raw.txt -o params.txt

# NUCLEI VULN SCANNING WITH PROFILE

echo "[+] Running CVE scans..."
nuclei -profile cves -l live.txt -o cve.txt

echo "[+] Running Misconfiguration scans..."
nuclei -profile misconfigurations -l live.txt -o misconfig.txt

echo "[+] Running Subdomain Takeover scans..."
nuclei -profile subdomain-takeovers -l live.txt -o takeover.txt

echo "[+] Running Sensitive Exposure / OSINT scans..."
nuclei -profile osint -l live.txt -o exposure.txt

# XSS PARAMETER SCANNING

echo "[+] Running Dalfox param scan..."
dalfox file params.txt --skip-bav -o result-xss.txt


echo "========================"
echo " SCAN COMPLETED "
echo "========================"
echo "[+] Live hosts: $(wc -l < live.txt)"
echo "[+] Params found: $(wc -l < params.txt)"
echo "[+] CVEs: $(wc -l < cve.txt)"
echo "[+] Misconfig: $(wc -l < misconfig.txt)"
echo "[+] Takeover: $(wc -l < takeover.txt)"
echo "[+] Exposure: $(wc -l < exposure.txt)"
echo "[+] XSS (Dalfox): $(wc -l < xss.txt)"
echo "Results saved in: results/$domain/"