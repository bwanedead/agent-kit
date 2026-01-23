---
name: profile-update
description: Update shared profiles repo files and push changes
allowed-tools: Bash
disable-model-invocation: true
argument-hint: "Describe the profile change and target file"
---

This is an instruction-only skill. There is no tool to run.

Use it when a user wants a quick change to a profile in `C:\projects\profiles`.

Steps:
1) Edit the repo profile file, never the system `$PROFILE` file.
   - Primary target: `C:\projects\profiles\Microsoft.PowerShell_profile.ps1`
2) If the "profile-update managed section" exists, add new entries there.
   Otherwise, append this block at the end and place new entries inside it:

   # --- profile-update managed section (do not edit) ---
   # This section is maintained by the profile-update skill.
   # Manual edits may be overwritten.
   # profile-update: jump <name> => <path>
   function <name> { Set-Location "<path>" }
   # --- end profile-update managed section ---

3) Keep diffs minimal and focused.
4) In `C:\projects\profiles`, run `git add`, `git commit`, and `git push` unless the user asks otherwise.
