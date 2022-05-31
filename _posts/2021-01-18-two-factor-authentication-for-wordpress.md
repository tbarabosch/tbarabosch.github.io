---
title: 'The easy way to two-factor authentication for WordPress with Two-Factor and Google Authenticator'
date: '2021-01-18T19:00:00+00:00'
author: tbarabosch
layout: post
image: /wp-content/uploads/2021/07/2fa_lock.jpg
categories:
    - 'Web Security'
tags:
    - 2FA
    - 'Backup Verification Codes'
    - 'Google Authenticator'
    - MFA
    - 'multi-factor authentication'
    - Two-Factor
    - 'two-factor authentication'
    - WordPress
---

WordPress is the most popular content management system (CMS). Therefore, it is also a very popular target for hackers. The default WordPress login requires a username and password combination. If hackers obtain your login credentials, there is no second line of defense and your WordPress site is theirs. [Two-factor authentication ](https://www.nist.gov/itl/applied-cybersecurity/tig/back-basics-multi-factor-authentication)(or sometimes multi-factor authentication) adds this second line of defense to your WordPress site. Every time you log in to your WordPress site, it’ll ask you for your username and password plus a second factor, e.g. a one-time password. This blog post shows you how to set up two-factor authentication for WordPress. I’ll use the WordPress plugin [Two-Factor](https://en-gb.wordpress.org/plugins/two-factor/) to set up two-factor authentication with [Google Authenticator](https://www.google.com/landing/2step/).

The default way to log in to your WordPress site is using a username and a password. If a hacker obtains them, then they can easily login into your site. For instance, Hackers may obtain your login credentials via [WordPress password bruteforcing](https://wordpress.org/support/article/brute-force-attacks/) or they may obtain them directly from your computer (e.g. via a Trojan horse). Therefore, I’ll recommend always use the second line of defense.

[Two-factor authentication](https://www.nist.gov/itl/applied-cybersecurity/tig/back-basics-multi-factor-authentication) is your second line of defense. In case somebody obtained your WordPress login credentials, they won’t be able to log in as long as they don’t have access to the second factor, e.g. the Google Authenticator app on your mobile phone. Because every time someone logs in to your WordPress site, it’ll ask for a username plus password and this aforementioned second factor. If the second factor is not provided, then no login will occur.

**A word of caution**: even though you use two-factor authentication for WordPress, you should not forget to **use strong passwords**. There are many online (e.g. [LastPass](https://www.lastpass.com/password-manager)) and offline (e.g. [KeePassXC](https://keepassxc.org/)) tools to generate and manage your passwords in a secure fashion.

## <span class="ez-toc-section" id="How_to_setup_two-factor_authentication_for_WordPress_with_Two-Factor"></span>How to setup two-factor authentication for WordPress with Two-Factor?<span class="ez-toc-section-end"></span>

In the following, I’ll show you how to set up two-factor authentication for WordPress with the plugin [Two-Factor](https://en-gb.wordpress.org/plugins/two-factor/). This plugin is open source and [developed on Github](https://github.com/wordpress/two-factor/). This means that there are many eyes looking at its source code, auditing it, and searching as well as fixing possible vulnerabilities in it.

Two-Factor offers you several options to implement two-factor authentication for your website:

- E-mail codes: your WordPress site sends a code to your email address that you must provide to log in
- **Time-Based One-Time Passwords (TOTP)**: you must provide a one-time password, e.g. from Google Authenticator
- FIDO Universal 2nd Factor (U2F): support for hardware security keys, e.g. [YubiKey](https://www.yubico.com/products/)
- **Backup Codes**: a list of pin codes for one-time usage

While the plugin offers several options, this article describes how to set up two-factor authentication with Time-Based One-Time Passwords (TOTP) using Google Authenticator as the primary second factor and backup codes as “last resort”, e.g. in case you lose your mobile phone.

### <span class="ez-toc-section" id="What_you_need_to_setup_two-factor_authentication_for_WordPress"></span>What you need to setup two-factor authentication for WordPress?<span class="ez-toc-section-end"></span>

Before we can start, please ensure that you have the following things ready:

- a recent WordPress installation with administrative access (Admin)
- a recent (Android) mobile phone with the [Google Authenticator app](https://play.google.com/store/apps/details?id=com.google.android.apps.authenticator2&hl=en_GB&gl=US)
- optional: pen and paper

### <span class="ez-toc-section" id="Two-Factor_installation"></span>Two-Factor installation<span class="ez-toc-section-end"></span>

First, we install the WordPress plugin [Two-Factor](https://en-gb.wordpress.org/plugins/two-factor/). Head over to *Plugins* → *Add New* and search for Two-Factor.

<figure class="wp-block-image size-large">![Two-Factor lets you setup two factor authen](https://0xc0decafe.com/wp-content/uploads/2021/01/two-factor-install.png)<figcaption>The WordPress plugin Two-Factor enables two-factor authentication for WordPress </figcaption></figure>Hit the *Install* button to install the plugin and then the *Activate* button to activate it. If the installation was successful, then you should see the additional option (Two-Factor Options) under *Users* → *Your Profile*.

### <span class="ez-toc-section" id="Google_Authenticator_installation"></span>Google Authenticator installation<span class="ez-toc-section-end"></span>

Before you can configure Two-Factor and integrate it with Google Authenticator, you’ll have to install Google Authenticator on your mobile phone. Open the Play Store app on your Android mobile phone, search for [Google Authenticator](https://play.google.com/store/apps/details?id=com.google.android.apps.authenticator2&hl=en_GB&gl=US), and install it.

<figure class="wp-block-image size-large">![](https://0xc0decafe.com/wp-content/uploads/2021/01/image-1.png)<figcaption>Google Authenticator in Google Play</figcaption></figure>Open the Google Authenticator app and tie it to your Google account, if needed. That’s it.

### <span class="ez-toc-section" id="Two-Factor_configuration_and_Google_Authenticator_integration"></span>Two-Factor configuration and Google Authenticator integration<span class="ez-toc-section-end"></span>

Now with both Two-Factor and Google Authenticator installed, you’ll configure Two-Factor to use *Time Based One-Time Passwords* (TOTP) with Google Authenticator. Head over to *Users* → *Your Profile* and scroll down to *Two-Factor Options*. Here you need to enable *Time Based One-Time Password* (TOTP) by checking the checkbox. Furthermore, set the radio button *Primary* since it will be your primary second factor in the future.

There will be a QR code that you have to scan with your Google Authenticator app (see next Screenshot). Open the Google Authenticator app and click the big plus (+) in the right bottom of the app to add your site. Scan the QR code and Google Authenticator will show you a new entry for your WordPress site with your username. To complete the integration, type in one six digit one-time pin from Google Authenticator in WordPress, and hit the *Submit* button.

<figure class="wp-block-image size-large">![](https://0xc0decafe.com/wp-content/uploads/2021/01/two-factor-user-1-1024x655.png)<figcaption>Users settings allows activation of two-factor authentication</figcaption></figure>### <span class="ez-toc-section" id="Backup_Verification_Codes"></span>Backup Verification Codes<span class="ez-toc-section-end"></span>

It’s always advisable to have a backup plan. For example, in case you lose your mobile phone or access to your Google account, you won’t be able to log in to your WordPress site. Therefore, you should use *Backup Verification Codes* as a backup plan. These are ten pin codes that you can use instead of your primary second factor, which is Google Authenticator.

Enable *Backup Verification Codes (Single Use)* as well but do not click the *Primary* radio button as shown in the next screenshot.

<figure class="wp-block-image size-large is-resized">![](https://0xc0decafe.com/wp-content/uploads/2021/01/two-factor-user-filled-out-1024x524.png)<figcaption>Two-factor authentication with primary Time-Based One-Time Password (TOTP) and activated Backup Verification Codes (Single Use) </figcaption></figure>You’ll see ten Backup Verification Codes similar to the next screenshot. Either you use your pen and paper and write them down or you download them and store them on your computer. The most secure way is to write them down on paper. Because if somebody gets access to your computer (e.g. via a Trojan horse) later on, they won’t find these codes on your computer. Therefore, they won’t be able to circumvent the two-factor authentication.

<figure class="wp-block-image size-large">![](https://0xc0decafe.com/wp-content/uploads/2021/01/two-factor-verification-codes.png)<figcaption>10 Backup Verification Codes generated and ready for download</figcaption></figure>### <span class="ez-toc-section" id="WordPress_login_with_Two-Factor_enabled"></span>WordPress login with Two-Factor enabled<span class="ez-toc-section-end"></span>

Now, you’re ready to test Two-Factor. Log out from your WordPress site and log in again. First, you’ll be asked for your default login credentials: username and password. But once you’ve entered them, you are now presented a new view similar to the following:

<figure class="wp-block-image size-large">![](https://0xc0decafe.com/wp-content/uploads/2021/01/two-factor-live.png)<figcaption>WordPress login asks for Authentication Code from Google Authenticator</figcaption></figure>This is the Two-Factor view that asks for your second factor. Pick up your Android mobile phone, open the Google Authenticator app, and get your authentication code (six digits). Be quick when typing them in because they’re only valid for a small amount of time. In the background, Two-Factor will talk to Google and verify the authentication code you’ve just typed in. If everything works out, then you’ll be logged in to your WordPress site as usual.

Perfect, you’ve just set up two-factor authentication for WordPress with Two-Factor and Google Authenticator!
