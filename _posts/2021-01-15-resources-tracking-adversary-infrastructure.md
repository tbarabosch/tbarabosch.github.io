---
title: 'Where to start tracking adversary infrastructure?'
date: '2021-01-15T22:18:33+00:00'
author: tbarabosch
layout: post
image: /wp-content/uploads/2021/01/tracking_infrastructure.jpg
categories:
    - 'Cyber Threat Intelligence'
tags:
    - APT29
    - APT32
    - BinaryEdge
    - Censys
    - CobaltStrike
    - 'Diamond Model'
    - DomainTools
    - 'Intrusion Analysis'
    - JARM
    - MASSCAN
    - Nmap
    - OilRig
    - pDNS
    - pypssl
    - sandworm
    - Shodan
---

**Last update: 2020-01-19**

Adversaries require infrastructure to support their operations and to ultimately achieve their goals like intelligence collection. Therefore, infrastructure is one of the four core features of the famous [Diamond Model of Intrusion Analysis](https://www.activeresponse.org/wp-content/uploads/2013/07/diamond.pdf). The proactive detection of adversary infrastructure can help cyber threat intelligence (CTI) teams detect this infrastructure even before the adversary has utilized it.

The quintessence here is that we are all lazy humans with our personal preferences and tendencies. Therefore, operational security (OpSec) is sometimes neglected for greater comfort. Tracking adversary infrastructure is based on the idea that we take data from past intrusions, identify patterns, which we then search for in the future. This initial data from past intrusions may be primary source data from incident response engagements or secondary source data from CTI blogs. Today, there are numerous sources that we can leverage to detect future adversary infrastructure: either we rely on third-party services like [Shodan](https://www.shodan.io/) or [Censys](https://censys.io/), to name a few, or we can run our own scanning infrastructure using, for instance, [MASSCAN](https://github.com/robertdavidgraham/masscan).

This blog post lists curated resources for tracking adversary infrastructure. The first section *Infrastructure tracking basics* lists introductory resources to get started. The next section *Examples of infrastructure tracking* comprises a list of read-worthy resources that showcase how to use the techniques described in the previous section. The third section *Infrastructure tracking automation* gives an overview of resources for those who wish to automate parts of the tracking process. Finally, I’ll present a list of (open source) tools and online services that are essential for this endeavor.

**Note**: This blog post should be considered a living document. I am planning to add more and more resources in the weeks.

- [Advanced Persistent Infrastructure Tracking](https://censys.io/advanced-persistent-infrastructure-tracking/) by [Nils Kuhnert](https://twitter.com/0x3c7) @ [Censys Blog](https://censys.io/resources/): This should be the first introductory article you read before you start tracking adversary infrastructure. It gives you the background on **why** this actually works, e.g. different teams with different skillsets set up the infrastructure and operate it. Using the online service Censys as an example, it shows how to use HTTP headers to track CobaltStrike infrastructure in general and certificate data to track APT29’s infrastructure. The blog post concludes with a bunch of useful tips for beginners.
- [Analyzing Network Infrastructure as Composite Objects](https://www.domaintools.com/resources/blog/analyzing-network-infrastructure-as-composite-objects) by [Joe Slowik](https://twitter.com/jfslowik) / [Domains Tools Blog](https://www.domaintools.com/resources/blog/): Good introductory post on malicious network infrastructure, mostly focusing on domain names, IP addresses, and SSL/TLS certificates. It encourages analysts not to treat these types of IoCs as atomic objects but rather as composite objects. CTI analysts should see the identification of new IoCs as an intermediate objective and leverage them for their long-term objective of understanding an adversary’s behavior and tendencies.
- [Extrapolating Adversary Intent Through Infrastructure](https://www.domaintools.com/resources/blog/extrapolating-adversary-intent-through-infrastructure) by [Joe Slowik](https://twitter.com/jfslowik) / [Domains Tools Blog](https://www.domaintools.com/resources/blog/): Often adversaries leverage themes in domain creation. For instance, this may help them to blend in with expected traffic on their victims’ networks (e.g. Microsoft-themed domain names). In this blog post, three case studies show how important the themes of domain names are. By studying them, we can infer the intentions and purposes of the adversary.
- Attribution of Advanced Persistent Threats: How to Identify the Actors Behind Cyber-Espionage (ISBN: 978-3662613122) by [Timo Steffens](https://twitter.com/Timo_Steffens): This book is the most comprehensive resource on threat actor attribution. Of course, infrastructure plays an important role in attribution. Therefore, a whole chapter is dedicated to this topic (Chapter 4). Personally, I would recommend this book to every CTI analyst.

## Examples of infrastructure tracking

There are several blog posts that prove that tracking adversary infrastructure works. It doesn’t matter if it’s APT or cybercrime infrastructure. The following are read-worthy articles that show how to apply the acquired knowledge to real-world data.

- [APT1- Exposing One of China’s Cyber Espionage Units](https://www.fireeye.com/content/dam/fireeye-www/services/pdfs/mandiant-apt1-report.pdf) by Mandiant: This report originally published in 2013 was unprecedented. It showed that a private-sector entity can deliver a very precise attribution of a nation-state actor. Furthermore, it introduced the three magical letters A-P-T to a wider audience. I believe that every CTI analyst should read this report, alone due to its historical value. The infrastructure tracking part starts on page 39 and comprises 11 pages.
- [Analyzing Cobalt Strike for Fun and Profit](https://www.randhome.io/blog/2020/12/20/analyzing-cobalt-strike-for-fun-and-profit/) by Etienne Maynier @ [randhome.io](https://www.randhome.io/): This article shows how the fingerprinting tools JARM and Shodan can be combined in order to unearth a significant part of live CobaltStrike CC servers. The servers are then contacted, Beacons are downloaded, and configuration information is extracted.
- [Identifying Critical Infrastructure Targeting through Network Creation](https://www.domaintools.com/resources/blog/identifying-critical-infrastructure-targeting-through-network-creation) by [Joe Slowik](https://twitter.com/jfslowik) / [Domains Tools Blog](https://www.domaintools.com/resources/blog/): This blog post shows how to use previous findings from other researchers in order to pivot on them to find further infrastructure. They focus on the infrastructure of APT34 / OilRig. At first, they pivot on email addresses that this actor utilized to register domains. One of the email addresses registered several domains that follow certain patterns, e.g. mimicking corporate/executive themes or referring to the People’s Republic of China (PRC). Pivoting on these domains allowed them to find further emails sent from this aforementioned infrastructure in several malware repositories. Subsequently, they unveiled a previously unknown phishing campaign. Even though there is no final conclusion on whether this is a related or completely separated phishing campaign, this finding may help other researchers in their future investigations.
- Sandworm: A New Era of Cyberwar and the Hunt for the Kremlin’s Most Dangerous Hackers (ISBN: 978-0525564638) by Andy Greenberg: Even though this is a nonfiction but also nontechnical book, it is a good read for long and cold winter evenings with some tracking of adversary infrastructure. This book tells the story of the hunt for the nation-state actor Sandworm, who is responsible for many high-profile cyber operations in recent history. Many reputable CTI analysts tell their part of their story.

## <span class="ez-toc-section" id="Infrastructure_tracking_automation"></span>Infrastructure tracking automation<span class="ez-toc-section-end"></span>

- [SCANdalous](https://www.fireeye.com/blog/threat-research/2020/07/scandalous-external-detection-using-network-scan-data-and-automation.html) by [Aaron Stephens](https://twitter.com/x04steve), [Andrew Thompson](https://twitter.com/anthomsec) / [FireEye Threat Research Blog](https://www.fireeye.com/blog/threat-research.html): SCANdalous is an in-house system of FireEye that proactively detects adversary infrastructure. However, the analyst is still in the loop. It is a very interesting example for those who wish to automate infrastructure tracking. Its main idea is to observe and collect data on adversaries (e.g. via incident response engagements), to identify patterns and characteristics (e.g. regarding the HTTP headers), to craft queries (e.g. for Shodan), and to monitor new results over time. There are also a [video presentation](https://www.youtube.com/watch?v=x1tEOkY-7JE) and [slides](https://raw.githubusercontent.com/aaronst/talks/master/scanttouchthis.pdf).

## Tools

- [Nmap](https://nmap.org/): Nmap is a network scanner that discovers hosts, scans ports, and detects service versions as well as operating systems. It comprises a scripting engine called Nmap Scritping Engine (NSE). There are already many NSE scripts available, for instance, to detect [Winnti infections](https://github.com/TKCERT/winnti-nmap-script) or grab [CobaltStrike Beacon configurations](https://github.com/whickey-r7/grab_beacon_config/blob/main/grab_beacon_config.nse). While versatile and well supported, it is not a solution to conduct mass scans. It is rather useful to, for example, scan suspicious hosts obtained from services like [Shodan](https://www.shodan.io/).
- [MASSCAN](https://github.com/robertdavidgraham/masscan): MASSCAN is an Internet-scale port scanner. It is blazing fast so that it can transmit up to 10 million packets per second. Under the hood, MASSCAN transmits packets asynchronously and comes with its own TCP/IP stack. While it is great to conduct superficial scans of many machines, it is not suited for in-depth scans like Nmap.
- [JARM](https://github.com/salesforce/jarm): JARM is a tool for active fingerprinting of Transport Layer Security (TLS) server. There is a blog post that goes[ into the details of JARM’s](<http://Easily Identify Malicious Servers on the Internet with JARM>) inner workings. Several online services like Shodan have added support for JARM. A great example of how to combine JARM and Shodan is [Analyzing Cobalt Strike for Fun and Profit](https://www.randhome.io/blog/2020/12/20/analyzing-cobalt-strike-for-fun-and-profit/).

## Online services

The following online services are essential tools for tracking adversary infrastructure. It is very unlikely that you have these capabilities in-house. Most of them offer free researcher accounts that usually come with a (very) limited daily quota. Nevertheless, this is sufficient for starters or for those who track only one or two adversaries very closely. Especially if you are planning to automate the tracking process, you require paid accounts with larger daily quotas.

### Search engines

- [Shodan](https://www.shodan.io/): Shodan crawls the Internet for publicly accessible devices and lets its users search within this data. [Search queries](https://help.shodan.io/the-basics/search-query-fundamentals) over the web interface allow many modifiers, but their real power lies in its [REST API](https://developer.shodan.io/api). There is also a [Python library](https://shodan.readthedocs.io/en/latest/) for this search engine.
- [Censys](https://censys.io/): Censys offers a quite comprehensive view of the current state of the Internet. It allows searching for [IPv4 hosts](https://censys.io/ipv4), [domains](https://censys.io/domain), and [certificates](https://censys.io/certificates). There is of course a REST API to automate searches.
- [BinaryEdge](https://www.binaryedge.io/): BinaryEdge is another service that offers a vast amount of Internet-wide data to search in. Naturally, they offer a [REST API ](https://docs.binaryedge.io/api-v2/)for automation purposes.

### Passive Databases

- [RiskIQ PassiveTotal](https://community.riskiq.com/): PassiveTotal aggregates web data from different sources (e.g. passive DNS, WHOIS, SSL/TLS certificates). This (historical) data allows us to quickly pivot on these sources and identify further adversary infrastructure.
- [CIRCL Passive SSL](https://www.circl.lu/services/passive-ssl/): Passive SSL is a historical database with historical X.509 certificates seen per IP address. It is only accessible via its REST API but they offer also a Python library called `pypssl`.
