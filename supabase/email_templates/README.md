# LingoBoop AI — Email Design System & Supabase Auth Templates

This directory contains the production-ready email templates for **LingoBoop AI**. Every email is designed with table-based layouts, inline styling, bulletproof VML buttons for Outlook, responsive mobile layouts, and high-resolution 3D illustrations of **Pano the Panda**, your official AI companion.

---

## 1. Templates Overview & Supabase Mapping

| Template Name | File Path | Supabase Dashboard Section | Mascot Action | Key Variables |
| :--- | :--- | :--- | :--- | :--- |
| **Password Reset** | `reset_password.html` | Authentication &rarr; Email Templates &rarr; **Reset Password** | Pano with Golden Key | `{{ .ConfirmationURL }}`, `{{ .Email }}` |
| **Confirm Signup** | `confirm_signup.html` | Authentication &rarr; Email Templates &rarr; **Confirm Signup** | Pano Celebrating with Confetti | `{{ .ConfirmationURL }}`, `{{ .Email }}` |
| **Magic Link** | `magic_link.html` | Authentication &rarr; Email Templates &rarr; **Magic Link** | Pano with Glowing Magic Letter | `{{ .ConfirmationURL }}`, `{{ .Email }}` |
| **Change Email Address** | `email_change.html` | Authentication &rarr; Email Templates &rarr; **Change Email Address** | Pano with Transfer Envelope | `{{ .ConfirmationURL }}`, `{{ .Email }}` |
| **Re-authentication** | `reauthentication.html` | Authentication &rarr; Email Templates &rarr; **Reauthentication** | Pano with Emerald Shield | `{{ .Token }}`, `{{ .Email }}` |
| **Invite User** | `invite_user.html` | Authentication &rarr; Email Templates &rarr; **Invite User** | Pano Waving Paws | `{{ .ConfirmationURL }}`, `{{ .Email }}` |

---

## 2. Public Mascot Assets on Supabase CDN

All mascot illustrations are uploaded to the public Supabase storage bucket `email-assets` on your project (`https://kmkvyhtwxhsweznzubrr.supabase.co`):

- **Password Reset**: `https://kmkvyhtwxhsweznzubrr.supabase.co/storage/v1/object/public/email-assets/pano_password_reset.jpg`
- **Welcome / Signup**: `https://kmkvyhtwxhsweznzubrr.supabase.co/storage/v1/object/public/email-assets/pano_welcome.jpg`
- **Verification Shield**: `https://kmkvyhtwxhsweznzubrr.supabase.co/storage/v1/object/public/email-assets/pano_verification.jpg`
- **Magic Link**: `https://kmkvyhtwxhsweznzubrr.supabase.co/storage/v1/object/public/email-assets/pano_magic_link.jpg`
- **Email Change**: `https://kmkvyhtwxhsweznzubrr.supabase.co/storage/v1/object/public/email-assets/pano_email_change.jpg`

---

## 3. Step-by-Step Instructions to Update Supabase Dashboard

Follow these steps to update your live emails in Supabase:

1. Log in to [Supabase Dashboard](https://supabase.com/dashboard).
2. Open your project: **`kmkvyhtwxhsweznzubrr`** (LingoBoom / LingoBoop).
3. In the left navigation menu, click **Authentication** (the lock icon).
4. Click **Email Templates** under the Configuration tab.
5. For each template:
   - **Reset Password**:
     - Subject: `Reset your LingoBoop AI password 🔑`
     - Body: Copy the full contents of `supabase/email_templates/reset_password.html` and paste into the HTML editor.
     - Click **Save changes**.
   - **Confirm Signup**:
     - Subject: `Welcome to LingoBoop AI! Confirm your email 🎉`
     - Body: Copy `supabase/email_templates/confirm_signup.html`.
     - Click **Save changes**.
   - **Magic Link**:
     - Subject: `Your LingoBoop AI magic login link ✨`
     - Body: Copy `supabase/email_templates/magic_link.html`.
     - Click **Save changes**.
   - **Change Email Address**:
     - Subject: `Confirm your new LingoBoop AI email address 📬`
     - Body: Copy `supabase/email_templates/email_change.html`.
     - Click **Save changes**.
   - **Reauthentication**:
     - Subject: `Your LingoBoop AI verification code 🛡️`
     - Body: Copy `supabase/email_templates/reauthentication.html`.
     - Click **Save changes**.
   - **Invite User**:
     - Subject: `You've been invited to LingoBoop AI! 🐾`
     - Body: Copy `supabase/email_templates/invite_user.html`.
     - Click **Save changes**.

---

## 4. How to Inspect Live Browser Previews

Open `supabase/email_templates/previews/index.html` in your web browser. It provides an interactive preview gallery with:
- Desktop (660px) and Mobile (390px iPhone) frames.
- Instant switching between all 6 templates.
- Realistic mock data (`shubham@example.com`, secure tokens, OTP codes).

